// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../common/ABILibrary.sol";
import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

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
        leaves = new IVerifier.VerificationPayload[](1);

        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.utilaAccount,
            0,
            new bytes(0),
            ProofLibrary.makeBitmask(true, true, false, true, new bytes(0))
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        descriptions = new string[](1);

        descriptions[0] = JsonLibrary.toJson(
            "UtilaAccount.call{value: any}()",
            "{}",
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.utilaAccount), "any"),
            new ParameterLibrary.Parameter[](0)
        );
    }

    function getSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        calls.calls[0] = new Call[](5);
        bytes memory emptyData = new bytes(0);
        calls.calls[0][0] = Call($.curator, $.utilaAccount, 1 ether, emptyData, true);
        calls.calls[0][1] = Call($.curator, $.utilaAccount, 0, emptyData, true);
        calls.calls[0][2] = Call(address(0xdead), $.utilaAccount, 1 ether, emptyData, false);
        calls.calls[0][3] = Call($.curator, address(0xdead), 1 ether, emptyData, false);
        calls.calls[0][4] = Call($.curator, $.utilaAccount, 1 ether, abi.encode(0x12345678), false); // not empty calldata
    }
}
