// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library auroBTCPreLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function getSubvault0Proofs(address curator, address recipient)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](2);
        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WBTC,
            0,
            abi.encodeCall(IERC20.approve, (recipient, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[1] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WBTC,
            0,
            abi.encodeCall(IERC20.transfer, (recipient, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.transfer, (address(type(uint160).max), 0))
            )
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address recipient)
        internal
        pure
        returns (string[] memory descriptions)
    {
        descriptions = new string[](2);
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2("to", Strings.toHexString(recipient), "amount", "any");
        descriptions[0] = JsonLibrary.toJson(
            string(abi.encodePacked("WBTC.approve(recipient, any)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString(curator), Strings.toHexString(Constants.WBTC), "0"),
            innerParameters
        );
        descriptions[1] = JsonLibrary.toJson(
            string(abi.encodePacked("WBTC.transfer(recipient, any)")),
            ABILibrary.getABI(IERC20.transfer.selector),
            ParameterLibrary.build(Strings.toHexString(curator), Strings.toHexString(Constants.WBTC), "0"),
            innerParameters
        );
    }

    function getSubvault0SubvaultCalls(
        address curator,
        address recipient,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.approve, (recipient, 0)), true);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.approve, (recipient, 1 ether)), true);
            tmp[i++] = Call(address(0xdead), Constants.WBTC, 0, abi.encodeCall(IERC20.approve, (recipient, 0)), false);
            tmp[i++] = Call(curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, (recipient, 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 1 wei, abi.encodeCall(IERC20.approve, (recipient, 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encode(IERC20.approve.selector, recipient, 0), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[0] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.transfer, (recipient, 0)), true);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.transfer, (recipient, 1 ether)), true);
            tmp[i++] = Call(address(0xdead), Constants.WBTC, 0, abi.encodeCall(IERC20.transfer, (recipient, 0)), false);
            tmp[i++] = Call(curator, address(0xdead), 0, abi.encodeCall(IERC20.transfer, (recipient, 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 1 wei, abi.encodeCall(IERC20.transfer, (recipient, 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encodeCall(IERC20.transfer, (address(0xdead), 0)), false);
            tmp[i++] = Call(curator, Constants.WBTC, 0, abi.encode(IERC20.transfer.selector, recipient, 0), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[1] = tmp;
        }
    }
}
