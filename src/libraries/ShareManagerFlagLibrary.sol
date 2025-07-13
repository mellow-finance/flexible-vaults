// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IShareManager.sol";

/// @title ShareManagerFlagLibrary
/// @notice Utility library for encoding and decoding bitmask flags used in ShareManager configuration.
/// @dev Flags are encoded into a single uint256, with specific bits representing distinct toggles or durations.
///
/// # Bitmask Layout
/// - [0]   `hasMintPause`
/// - [1]   `hasBurnPause`
/// - [2]   `hasTransferPause`
/// - [3]   `hasWhitelist`
/// - [4]   `hasTransferWhitelist`
/// - [5..36]   `globalLockup` (32 bits)
/// - [37..68]  `targetedLockup` (32 bits)
library ShareManagerFlagLibrary {
    /// @notice Checks if the minting pause flag is enabled
    /// @param mask Encoded flags
    /// @return True if minting is paused
    function hasMintPause(uint256 mask) internal pure returns (bool) {
        return (mask & 1) != 0;
    }

    /// @notice Checks if the burning pause flag is enabled
    /// @param mask Encoded flags
    /// @return True if burning is paused
    function hasBurnPause(uint256 mask) internal pure returns (bool) {
        return (mask & 2) != 0;
    }

    /// @notice Checks if transfer pause is enabled
    /// @param mask Encoded flags
    /// @return True if transfers are paused
    function hasTransferPause(uint256 mask) internal pure returns (bool) {
        return (mask & 4) != 0;
    }

    /// @notice Checks if a whitelist is required for deposits
    /// @param mask Encoded flags
    /// @return True if deposit whitelist is enforced
    function hasWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 8) != 0;
    }

    /// @notice Checks if transfer whitelist is enforced
    /// @param mask Encoded flags
    /// @return True if transfer whitelist is enforced
    function hasTransferWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 16) != 0;
    }

    /// @notice Extracts the global lockup duration from the mask
    /// @param mask Encoded flags
    /// @return Global lockup period in seconds
    function getGlobalLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 5);
    }

    /// @notice Extracts the targeted lockup duration from the mask
    /// @param mask Encoded flags
    /// @return Targeted lockup period in seconds
    function getTargetedLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 37);
    }

    /// @notice Encodes a Flags struct into a single uint256 mask
    /// @param f Flags struct containing individual settings
    /// @return Bitmask encoding all flag values
    function createMask(IShareManager.Flags calldata f) internal pure returns (uint256) {
        return (f.hasMintPause ? 1 : 0) | (f.hasBurnPause ? 2 : 0) | (f.hasTransferPause ? 4 : 0)
            | (f.hasWhitelist ? 8 : 0) | (f.hasTransferWhitelist ? 16 : 0) | (uint256(f.globalLockup) << 5)
            | (uint256(f.targetedLockup) << 37);
    }
}
