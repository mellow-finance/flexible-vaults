// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

/// @notice Interface for base module functionality shared across all modules
/// @dev Provides basic utilities such as raw storage access, ERC721 receiver support and `receive()` callback
interface IBaseModule is IERC721Receiver {
    /// @notice Returns a reference to a storage slot as a `StorageSlot.Bytes32Slot` struct
    /// @param slot The keccak256-derived storage slot identifier
    /// @return A struct exposing the `.value` field stored at the given slot
    function getStorageAt(bytes32 slot) external pure returns (StorageSlot.Bytes32Slot memory);
}
