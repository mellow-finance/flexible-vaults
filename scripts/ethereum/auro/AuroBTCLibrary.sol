// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../../common/ArraysLibrary.sol";
import {Permissions} from "../../common/Permissions.sol";
import {ProofLibrary} from "../../common/ProofLibrary.sol";

import "../../../src/permissions/protocols/ERC20Verifier.sol";
import {Call, Factory, IVerifier, ProtocolDeployment, SubvaultCalls} from "../../common/interfaces/Imports.sol";
import "../Constants.sol";

library AuroBTCLibrary {
    function createERC20Verifier(
        address proxyAdmin,
        address curator,
        address recipient,
        address asset,
        Factory erc20VerifierFactory,
        string memory storageKey
    ) internal returns (address erc20Verifier, bytes32 merkleRoot, SubvaultCalls memory calls) {
        // Get the ERC20Verifier implementation from the factory
        ERC20Verifier erc20VerifierImpl = ERC20Verifier(erc20VerifierFactory.implementationAt(0));

        address[] memory holders = new address[](3);
        bytes32[] memory roles = new bytes32[](3);

        holders[0] = asset;
        roles[0] = erc20VerifierImpl.ASSET_ROLE();

        holders[1] = curator;
        roles[1] = erc20VerifierImpl.CALLER_ROLE();

        holders[2] = recipient;
        roles[2] = erc20VerifierImpl.RECIPIENT_ROLE();

        erc20Verifier = erc20VerifierFactory.create(0, proxyAdmin, abi.encode(proxyAdmin, holders, roles));

        IVerifier.VerificationPayload[] memory leaves = new IVerifier.VerificationPayload[](1);
        leaves[0] = IVerifier.VerificationPayload({
            verificationType: IVerifier.VerificationType.CUSTOM_VERIFIER,
            verificationData: abi.encode(erc20Verifier),
            proof: new bytes32[](0)
        });

        IVerifier.VerificationPayload[] memory leavesWithProofs;
        (merkleRoot, leavesWithProofs) = ProofLibrary.generateMerkleProofs(leaves);

        Call[][] memory callsArray = new Call[][](1);
        callsArray[0] = new Call[](2);

        callsArray[0][0] = Call({
            who: curator,
            where: asset,
            value: 0,
            data: abi.encodeWithSignature("transfer(address,uint256)", recipient, 0),
            verificationResult: true
        });

        callsArray[0][1] = Call({
            who: curator,
            where: asset,
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", recipient, 0),
            verificationResult: true
        });

        calls = SubvaultCalls({payloads: leavesWithProofs, calls: callsArray});

        string[] memory descriptions = new string[](1);
        descriptions[0] = string(
            abi.encodePacked(
                "Curator can transfer/approve wBTC to recipient using ERC20Verifier at ",
                _addressToString(erc20Verifier)
            )
        );

        ProofLibrary.storeProofs(storageKey, merkleRoot, leavesWithProofs, descriptions);
    }

    function _addressToString(address addr) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory data = abi.encodePacked(addr);
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
