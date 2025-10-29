// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/GenerateConfig.sol";

import "../common/protocols/OFTLibrary.sol";
import "./Constants.sol";
import "./strETHLibrary.sol";

/// @title GenerateConfig_Ethereum_strETH
/// @notice Verification script for Ethereum strETH vault subvault calls
/// @dev Inherits from VerifySubvaultCallsBase and provides strETH-specific configuration
contract GenerateConfig_Ethereum_strETH is GenerateConfig {
    // Ethereum strETH vault configuration
    // Configure which subvault to test by changing this address
    // Subvault 0: 0x90c983DC732e65DB6177638f0125914787b8Cb78
    // Subvault 1: 0x60f3918B27A06Ea0f5Cc18d1068bAAae9e5DF800
    // Subvault 2: 0x75ab2f27BAabb2A1fB1d83C53f952f2C9Ff0B849
    // Subvault 3: 0x60AcCBd1600C84A7fc97a0C99fFba9dC4CA84E14
    address constant SUBVAULT = 0x90c983DC732e65DB6177638f0125914787b8Cb78; // Subvault 0 (default)

    address constant CURATOR = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address constant ACTIVE_VAULT_ADMIN = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;

    function getSubvaultAddress() internal pure override returns (address) {
        return SUBVAULT;
    }

    function getCuratorAddress() internal pure override returns (address) {
        return CURATOR;
    }

    function getActiveVaultAdmin() internal pure override returns (address) {
        return ACTIVE_VAULT_ADMIN;
    }

    function getSubvaultCalls(address subvaultAddress) internal view override returns (SubvaultCalls memory calls) {
        // Determine which subvault this is based on address
        if (subvaultAddress == 0x90c983DC732e65DB6177638f0125914787b8Cb78) {
            // Subvault 0
            (, IVerifier.VerificationPayload[] memory leaves) = strETHLibrary.getSubvault0Proofs(CURATOR);
            calls = strETHLibrary.getSubvault0SubvaultCalls(CURATOR, leaves);
        } else if (subvaultAddress == 0x60f3918B27A06Ea0f5Cc18d1068bAAae9e5DF800) {
            // Subvault 1
            (, IVerifier.VerificationPayload[] memory leaves) =
                strETHLibrary.getSubvault1Proofs(CURATOR, subvaultAddress);
            calls = strETHLibrary.getSubvault1SubvaultCalls(CURATOR, subvaultAddress, leaves);
        } else if (subvaultAddress == 0x75ab2f27BAabb2A1fB1d83C53f952f2C9Ff0B849) {
            // Subvault 2
            (, IVerifier.VerificationPayload[] memory leaves) =
                strETHLibrary.getSubvault2Proofs(CURATOR, subvaultAddress);
            calls = strETHLibrary.getSubvault2SubvaultCalls(CURATOR, subvaultAddress, leaves);
        } else if (subvaultAddress == 0x60AcCBd1600C84A7fc97a0C99fFba9dC4CA84E14) {
            // Subvault 3
            (, IVerifier.VerificationPayload[] memory leaves) =
                strETHLibrary.getSubvault3Proofs(CURATOR, subvaultAddress);
            calls = strETHLibrary.getSubvault3SubvaultCalls(CURATOR, subvaultAddress, leaves);
        } else {
            revert("Unknown subvault address for strETH");
        }
    }

    function getDescriptions(address subvaultAddress) internal view override returns (string[] memory descriptions) {
        // Determine which subvault this is based on address
        if (subvaultAddress == 0x90c983DC732e65DB6177638f0125914787b8Cb78) {
            // Subvault 0
            descriptions = strETHLibrary.getSubvault0Descriptions(CURATOR);
        } else if (subvaultAddress == 0x60f3918B27A06Ea0f5Cc18d1068bAAae9e5DF800) {
            // Subvault 1
            descriptions = strETHLibrary.getSubvault1Descriptions(CURATOR, subvaultAddress);
        } else if (subvaultAddress == 0x75ab2f27BAabb2A1fB1d83C53f952f2C9Ff0B849) {
            // Subvault 2
            descriptions = strETHLibrary.getSubvault2Descriptions(CURATOR, subvaultAddress);
        } else if (subvaultAddress == 0x60AcCBd1600C84A7fc97a0C99fFba9dC4CA84E14) {
            // Subvault 3
            descriptions = strETHLibrary.getSubvault3Descriptions(CURATOR, subvaultAddress);
        } else {
            revert("Unknown subvault address for strETH");
        }
    }

    function getJsonName() internal pure override returns (string memory) {
        // Determine JSON name based on which subvault is configured
        if (SUBVAULT == 0x90c983DC732e65DB6177638f0125914787b8Cb78) {
            return "ethereum:strETH:subvault0";
        } else if (SUBVAULT == 0x60f3918B27A06Ea0f5Cc18d1068bAAae9e5DF800) {
            return "ethereum:strETH:subvault1";
        } else if (SUBVAULT == 0x75ab2f27BAabb2A1fB1d83C53f952f2C9Ff0B849) {
            return "ethereum:strETH:subvault2";
        } else if (SUBVAULT == 0x60AcCBd1600C84A7fc97a0C99fFba9dC4CA84E14) {
            return "ethereum:strETH:subvault3";
        } else {
            return "ethereum:strETH:unknown";
        }
    }
}
