// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "../../src/interfaces/permissions/IVerifier.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "./ParameterLibrary.sol";

library JsonLibrary {
    function _this() private pure returns (VmSafe) {
        return VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
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
            json = string(abi.encodePacked(json, (i == 0 ? '"' : ',\n"'), p[i].name, '":"', p[i].value, '"'));
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
}
