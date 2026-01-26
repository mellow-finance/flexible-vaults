// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IAngleDistributor} from "../interfaces/IAngleDistributor.sol";
import "../interfaces/Imports.sol";

library AngleDistributorLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address angleDistributor;
    }

    function getAngleDistributorProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](1);

        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.angleDistributor,
            0,
            abi.encodeCall(IAngleDistributor.toggleOperator, ($.subvault, address(0))),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IAngleDistributor.toggleOperator, (address(type(uint160).max), address(0)))
            )
        );
    }

    function getAngleDistributorDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](1);

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = innerParameters.add("user", Strings.toHexString($.subvault));
        innerParameters = innerParameters.addAny("operator");

        descriptions[0] = JsonLibrary.toJson(
            string(abi.encodePacked("AngleDistributor.toggleOperator(user=", $.subvaultName, ", ", "operator=Any)")),
            ABILibrary.getABI(IAngleDistributor.toggleOperator.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.angleDistributor), "0"),
            innerParameters
        );
    }

    function getAngleDistributorCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        uint256 index = 0;
        calls = new Call[][](1);

        // IAngleDistributor.toggleOperator
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;

            tmp[i++] = Call(
                $.curator,
                $.angleDistributor,
                0,
                abi.encodeCall(IAngleDistributor.toggleOperator, ($.subvault, address(0))),
                true
            );
            tmp[i++] = Call(
                $.curator,
                $.angleDistributor,
                0,
                abi.encodeCall(IAngleDistributor.toggleOperator, (address(0xdead), address(0))),
                false
            );
            tmp[i++] = Call(
                address(0xdead),
                $.angleDistributor,
                0,
                abi.encodeCall(IAngleDistributor.toggleOperator, ($.subvault, address(0))),
                false
            );
            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IAngleDistributor.toggleOperator, ($.subvault, address(0))),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls[0] = tmp;
        }
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 data) internal pure returns (address) {
        return address(uint160(uint256(data)));
    }
}
