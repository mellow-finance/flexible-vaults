// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {AcceptanceLibrary} from "./AcceptanceLibrary.sol";
import {ArraysLibrary} from "./ArraysLibrary.sol";
import {ProofLibrary} from "./ProofLibrary.sol";
import {Call, SubvaultCalls} from "./interfaces/Imports.sol";

import {Subvault} from "../../src/vaults/Subvault.sol";
import {IVerifier} from "../../src/interfaces/modules/IVerifierModule.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

abstract contract GenerateConfig is Script {
    // ===== CONFIGURATION (Virtual Functions) =====
    // Override these in derived contracts

    /// @notice Returns the subvault address to test
    function getSubvaultAddress() internal view virtual returns (address);

    /// @notice Returns the curator address
    function getCuratorAddress() internal view virtual returns (address);

    /// @notice Returns the admin address that can set merkle roots
    function getActiveVaultAdmin() internal view virtual returns (address);

    /// @notice Returns the subvault calls for the given subvault
    /// @param subvaultAddress The address of the subvault
    function getSubvaultCalls(address subvaultAddress) internal view virtual returns (SubvaultCalls memory calls);

    /// @notice Returns human-readable descriptions for each proof
    /// @param subvaultAddress The address of the subvault
    function getDescriptions(address subvaultAddress) internal view virtual returns (string[] memory descriptions);

    /// @notice Returns the JSON file name for storing proofs (e.g., "ethereum:strETH:subvault0")
    function getJsonName() internal view virtual returns (string memory);

    // =================================================

    function run() external {
        address subvaultAddress = getSubvaultAddress();
        address admin = getActiveVaultAdmin();

        console2.log("==============================================");
        console2.log("Testing subvault calls");
        console2.log("Subvault:", subvaultAddress);
        console2.log("==============================================\n");

        IVerifier verifier = Subvault(payable(subvaultAddress)).verifier();

        console2.log("Verifier address:", address(verifier));
        console2.log("Current on-chain merkle root:", vm.toString(verifier.merkleRoot()));
        console2.log("");

        // Generate proofs and calls from library
        SubvaultCalls memory calls = getSubvaultCalls(subvaultAddress);
        (bytes32 newMerkleRoot,) = ProofLibrary.generateMerkleProofs(calls.payloads);

        console2.log("Generated merkle root:", vm.toString(newMerkleRoot));
        console2.log("Number of leaves:", calls.payloads.length);
        console2.log("");

        // Check if root needs update
        bool rootMatches = (verifier.merkleRoot() == newMerkleRoot);
        if (rootMatches) {
            console2.log("[OK] Merkle root matches on-chain (no update needed)");
        } else {
            console2.log("[!] Merkle root differs from on-chain (update required)");
        }
        console2.log("");

        // Simulate setting the merkle root
        console2.log("=== Simulating merkle root update ===");
        vm.startPrank(admin);
        verifier.setMerkleRoot(newMerkleRoot);
        vm.stopPrank();

        require(verifier.merkleRoot() == newMerkleRoot, "Failed to set merkle root");
        console2.log("[OK] Merkle root set successfully");
        console2.log("");

        // Verify all calls
        console2.log("=== Verifying all calls ===");
        uint256 totalCalls = 0;
        uint256 successCount = 0;

        for (uint256 j = 0; j < calls.payloads.length; j++) {
            Call[] memory callSet = calls.calls[j];
            IVerifier.VerificationPayload memory payload = calls.payloads[j];

            (uint256 success, uint256 total) = _verifyCalls(verifier, callSet, payload, j);
            successCount += success;
            totalCalls += total;
        }

        console2.log("");
        console2.log("==============================================");
        console2.log("RESULTS:");
        console2.log("  Passed:", successCount);
        console2.log("  Total:", totalCalls);
        console2.log("==============================================");

        require(successCount == totalCalls, "Some call verifications failed");

        // Store proofs to JSON file
        console2.log("");
        console2.log("=== Storing proofs to JSON ===");
        string[] memory descriptions = getDescriptions(subvaultAddress);
        string memory jsonName = getJsonName();
        ProofLibrary.storeProofs(jsonName, newMerkleRoot, calls.payloads, descriptions);
        console2.log(string.concat("[OK] Proofs saved to: scripts/jsons/", jsonName, ".json"));
    }

    function _verifyCalls(
        IVerifier verifier,
        Call[] memory callSet,
        IVerifier.VerificationPayload memory payload,
        uint256 payloadIndex
    ) internal view returns (uint256 successCount, uint256 totalCount) {
        totalCount = callSet.length;
        successCount = 0;

        for (uint256 k = 0; k < callSet.length; k++) {
            Call memory call = callSet[k];
            bool result = verifier.getVerificationResult(call.who, call.where, call.value, call.data, payload);

            if (result == call.verificationResult) {
                successCount++;
            } else {
                console2.log("");
                console2.log("[FAIL] VERIFICATION FAILED");
                console2.log("  Payload:", payloadIndex);
                console2.log("  Call:", k);
                console2.log("  Expected:", call.verificationResult);
                console2.log("  Got:", result);
                console2.log("  Caller:", call.who);
                console2.log("  Target:", call.where);
                console2.log("  Value:", call.value);
                console2.log("");
            }
        }

        string memory status = successCount == totalCount ? "[OK]" : "[FAIL]";
        console2.log(
            string.concat(
                status,
                " Payload ",
                vm.toString(payloadIndex),
                ": ",
                vm.toString(successCount),
                "/",
                vm.toString(totalCount),
                " calls passed"
            )
        );
    }
}
