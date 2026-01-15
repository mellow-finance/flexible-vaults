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
import {CCTPLibrary} from "../common/protocols/CCTPLibrary.sol";

library msvUSDLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function _getCCTPParams(
        address curator,
        address srcSubvault,
        address dstSubvault
    ) internal pure returns (CCTPLibrary.Info memory) {
        return
            CCTPLibrary.Info({
            curator: curator,
            subvault: srcSubvault,
            subvaultName: "subvault0",
            tokenMessenger: Constants.CCTP_ETHEREUM_TOKEN_MESSENGER,
            messageTransmitter: Constants.CCTP_ETHEREUM_MESSAGE_TRANSMITTER,
            destinationDomain: Constants.CCTP_ARBITRUM_DOMAIN,
            mintRecipient: dstSubvault,
            burnToken: Constants.USDC,
            caller: address(0)
        });
    }

    function getSubvault0Proofs(address curator, address srcSubvault, address dstSubvault)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {

        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;

        CCTPLibrary.Info memory cctpInfo = _getCCTPParams(curator, srcSubvault, dstSubvault);
        iterator = ArraysLibrary.insert(
            leaves, CCTPLibrary.getCCTPProofs(bitmaskVerifier, cctpInfo), iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address srcSubvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        descriptions = new string[](50);
        uint256 iterator = 0;

        CCTPLibrary.Info memory cctpInfo = _getCCTPParams(curator, srcSubvault, address(0xdead));
        iterator = ArraysLibrary.insert(
            descriptions, CCTPLibrary.getCCTPDescriptions(cctpInfo), iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }
}
