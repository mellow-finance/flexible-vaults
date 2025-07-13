// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title SlotLibrary
/// @notice Library for computing deterministic and collision-resistant storage slots
/// @dev Used to generate unique storage slots for upgradeable modules using string identifiers
library SlotLibrary {
    /// @notice Computes a unique storage slot based on the module's identifiers
    /// @param contractName Logical contract/module name (e.g., "ShareModule")
    /// @param name Human-readable instance name (e.g., "Mellow")
    /// @param version Version number for the module configuration
    /// @return A bytes32 value representing the derived storage slot
    function getSlot(string memory contractName, string memory name, uint256 version) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint256(keccak256(abi.encodePacked("mellow.flexible-vaults.storage.", contractName, name, version))) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }
}
