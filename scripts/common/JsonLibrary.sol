// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "../../src/interfaces/permissions/IVerifier.sol";

import {IBoringOnChainQueue} from "./interfaces/IBoringOnChainQueue.sol";
import {ILayerZeroOFT} from "./interfaces/ILayerZeroOFT.sol";
import {IMorpho} from "./interfaces/IMorpho.sol";

import {IPositionManagerV3} from "./interfaces/IPositionManagerV3.sol";
import {CCIPClient} from "./libraries/CCIPClient.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "./ParameterLibrary.sol";

library JsonLibrary {
    function _this() private pure returns (VmSafe) {
        return VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    }

    function toJsonStringArray(ParameterLibrary.Parameter[][] memory parameters)
        internal
        pure
        returns (string memory result)
    {
        for (uint256 i = 0; i < parameters.length; i++) {
            result =
                (i == 0 ? toJsonMap(parameters[i]) : string(abi.encodePacked(result, ", ", toJsonMap(parameters[i]))));
        }
        result = string(abi.encodePacked("[", result, "]"));
    }

    function toJsonMap(ParameterLibrary.Parameter[] memory parameters) internal pure returns (string memory result) {
        for (uint256 i = 0; i < parameters.length; i++) {
            result = (
                i == 0
                    ? toString(parameters[i], false)
                    : string(abi.encodePacked(result, ", ", toString(parameters[i], false)))
            );
        }
        result = string(abi.encodePacked("{", result, "}"));
    }

    function toString(ParameterLibrary.Parameter memory parameter, bool wrap)
        internal
        pure
        returns (string memory result)
    {
        if (wrap) {
            result = string(abi.encodePacked('{"', parameter.name, '":"', parameter.value, '"}'));
        } else {
            result = string(abi.encodePacked('"', parameter.name, '":"', parameter.value, '"'));
        }
    }

    function toJson(IBoringOnChainQueue.OnChainWithdraw memory $) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"nonce": "any", ',
                ' "user": "',
                _this().toString($.user),
                '",',
                ' "assetOut": "',
                _this().toString($.assetOut),
                '",',
                ' "amountOfShares": "any", ',
                ' "amountOfAssets": "any", ',
                ' "creationTime": "any", ',
                ' "secondsToMaturity": "any", ',
                ' "secondsToDeadline": "any", ',
                "}"
            )
        );
    }

    function toJson(ILayerZeroOFT.SendParam memory params) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"dstEid": "',
                _this().toString(params.dstEid),
                '", ',
                ' "to": "',
                _this().toString(params.to),
                '",',
                ' "amountLD": "any",',
                ' "minAmountLD": "any",',
                ' "extraOptions": "0x",',
                ' "composeMsg": "0x",',
                ' "oftCmd": "0x"',
                "}"
            )
        );
    }

    function toJson(ILayerZeroOFT.MessagingFee memory /* params */ ) internal pure returns (string memory json) {
        json = string(abi.encodePacked("{", '"nativeFee": "any",', ' "lzTokenFee": "0"}'));
    }

    function toJson(CCIPClient.EVM2AnyMessage memory message) internal pure returns (string memory json) {
        ParameterLibrary.Parameter[][] memory tokenAmounts =
            new ParameterLibrary.Parameter[][](message.tokenAmounts.length);
        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            tokenAmounts[i] =
                ParameterLibrary.add2("token", _this().toString(message.tokenAmounts[i].token), "amount", "any");
        }
        json = string(
            abi.encodePacked(
                '{"receiver": "',
                _this().toString(message.receiver),
                '", ',
                '"data": "0x",',
                '"tokenAmounts": ',
                toJsonStringArray(tokenAmounts),
                ",",
                '"feeToken": "0x0000000000000000000000000000000000000000",',
                '"extraArgs": "0x181dcf1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"}'
            )
        );
    }

    function toJson(IPositionManagerV3.CollectParams memory params) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"tokenId": "any",',
                ' "recipient": "',
                _this().toString(params.recipient),
                '",',
                ' "amount0Max": "any",',
                ' "amount1Max": "any"',
                "}"
            )
        );
    }

    function toJson(IPositionManagerV3.IncreaseLiquidityParams memory params)
        internal
        pure
        returns (string memory json)
    {
        json = string(
            abi.encodePacked(
                '{"tokenId": "',
                _this().toString(params.tokenId),
                '", ',
                ' "amount0Desired": "any",',
                ' "amount1Desired": "any",',
                ' "amount0Min": "any",',
                ' "amount1Min": "any",',
                ' "deadline": "any"',
                "}"
            )
        );
    }

    function toJson(IPositionManagerV3.DecreaseLiquidityParams memory) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"tokenId": "any",',
                ' "liquidity": "any",',
                ' "amount0Min": "any",',
                ' "amount1Min": "any",',
                ' "deadline": "any"',
                "}"
            )
        );
    }

    function toJson(
        string memory description,
        string memory abi_,
        ParameterLibrary.Parameter[] memory parameters,
        ParameterLibrary.Parameter[] memory innerParameters
    ) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"description": "',
                description,
                '", ',
                '"abi": ',
                abi_,
                ', "parameters": ',
                toJson(parameters),
                ', "innerParameters": ',
                toJson(innerParameters),
                "}"
            )
        );
    }

    function toJson(ParameterLibrary.Parameter[] memory p) internal pure returns (string memory json) {
        json = "{";
        for (uint256 i = 0; i < p.length; i++) {
            if (p[i].isNestedJson) {
                json = string(abi.encodePacked(json, (i == 0 ? '"' : ',\n"'), p[i].name, '":', p[i].value));
            } else {
                json = string(abi.encodePacked(json, (i == 0 ? '"' : ',\n"'), p[i].name, '":"', p[i].value, '"'));
            }
        }
        json = string(abi.encodePacked(json, "}"));
    }

    function toJson(
        string memory title,
        bytes32 root,
        IVerifier.VerificationPayload[] memory leaves,
        string[] memory descriptions
    ) internal pure returns (string memory json) {
        json = string(
            abi.encodePacked(
                '{"title": "',
                title,
                '",\n',
                '"merkle_root": "',
                _this().toString(root),
                '",\n',
                '"merkle_proofs": ',
                toJson(leaves, descriptions),
                "}"
            )
        );
    }

    function toJson(IVerifier.VerificationPayload memory p, string memory description)
        internal
        pure
        returns (string memory json)
    {
        json = string(
            abi.encodePacked(
                '{ "verificationType" : ',
                _this().toString(uint256(p.verificationType)),
                ', "description": ',
                description,
                ', "verificationData": "',
                _this().toString(p.verificationData),
                '", "proof": ',
                toJson(p.proof),
                "}"
            )
        );
    }

    function toJson(IVerifier.VerificationPayload[] memory p, string[] memory descriptions)
        internal
        pure
        returns (string memory json)
    {
        string[] memory array = new string[](p.length);
        for (uint256 i = 0; i < array.length; i++) {
            array[i] = toJson(p[i], descriptions[i]);
        }
        return toJson(array, false);
    }

    function toJson(string[] memory array) internal pure returns (string memory json) {
        json = toJson(array, true);
    }

    function toJson(string[] memory array, bool withBrackets) internal pure returns (string memory json) {
        json = "[";
        for (uint256 i = 0; i < array.length; i++) {
            if (withBrackets) {
                json = string(abi.encodePacked(json, (i == 0 ? '"' : ', "'), array[i], '"'));
            } else {
                json = string(abi.encodePacked(json, (i == 0 ? "" : ", "), array[i], ""));
            }
        }
        json = string(abi.encodePacked(json, "]"));
    }

    function toJson(bytes32[] memory a) internal pure returns (string memory) {
        string[] memory array = new string[](a.length);
        for (uint256 i = 0; i < array.length; i++) {
            array[i] = _this().toString(a[i]);
        }
        return toJson(array);
    }

    function toJson(IMorpho.MarketParams memory marketParams) internal pure returns (string memory json) {
        ParameterLibrary.Parameter[] memory params;
        params = ParameterLibrary.build("loanToken", _this().toString(marketParams.loanToken));
        params = ParameterLibrary.add(params, "collateralToken", _this().toString(marketParams.collateralToken));
        params = ParameterLibrary.add(params, "oracle", _this().toString(marketParams.oracle));
        params = ParameterLibrary.add(params, "irm", _this().toString(marketParams.irm));
        params = ParameterLibrary.add(params, "lltv", _this().toString(marketParams.lltv));
        return toJson(params);
    }
}
