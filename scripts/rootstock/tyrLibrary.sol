// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../common/ABILibrary.sol";
import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";
import {IERC20} from "lib/contracts/src/contracts/interfaces/IERC20.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library tyrLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address utilaAccount;
        address wrbtc;
    }

    function getSubvault0Data(Info memory $)
        internal
        view
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls
        )
    {
        (merkleRoot, leaves) = getSubvault0Proofs($);
        descriptions = getSubvault0Descriptions($);
        calls = getSubvault0Calls($, leaves);
    }

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](3);

        WethLibrary.Info memory wethInfo = WethLibrary.Info({curator: $.curator, weth: $.wrbtc});

        leaves[0] = WethLibrary.getWethDepositProof(bitmaskVerifier, wethInfo);
        leaves[1] = WethLibrary.getWethWithdrawProof(bitmaskVerifier, wethInfo);

        leaves[2] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.wrbtc,
            0,
            abi.encodeCall(IERC20.transfer, ($.utilaAccount, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.transfer, (address(type(uint160).max), 0))
            )
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        descriptions = new string[](3);

        WethLibrary.Info memory wethInfo = WethLibrary.Info({curator: $.curator, weth: $.wrbtc});
        descriptions[0] = WethLibrary.getWethDepositDescription(wethInfo);
        descriptions[1] = WethLibrary.getWethWithdrawDescription(wethInfo);
        descriptions[2] = JsonLibrary.toJson(
            "IERC20(WRBTC).transfer(to=UtilaAccount, amount=any)",
            ABILibrary.getABI(IERC20.transfer.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.wrbtc), "0"),
            ParameterLibrary.build("to", Strings.toHexString($.utilaAccount)).addAny("amount")
        );
    }

    function getSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        WethLibrary.Info memory wethInfo = WethLibrary.Info({curator: $.curator, weth: $.wrbtc});
        calls.calls[0] = WethLibrary.getWethDepositCalls(wethInfo);
        calls.calls[1] = WethLibrary.getWethWithdrawCalls(wethInfo);

        {
            calls.calls[2] = new Call[](5);
            calls.calls[2][0] =
                Call($.curator, $.wrbtc, 0, abi.encodeCall(IERC20.transfer, ($.utilaAccount, 1 ether)), true);
            calls.calls[2][1] =
                Call(address(0xdead), $.wrbtc, 1 wei, abi.encodeCall(IERC20.transfer, ($.utilaAccount, 1 ether)), false);
            calls.calls[2][2] =
                Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.transfer, ($.utilaAccount, 1 ether)), false);
            calls.calls[2][3] =
                Call($.curator, $.wrbtc, 0, abi.encodeCall(IERC20.transfer, (address(0xdead), 1 ether)), false);
            calls.calls[2][4] =
                Call($.curator, $.wrbtc, 0, abi.encode(IERC20.transfer.selector, $.utilaAccount, 1 ether), false);
        }
    }
}
