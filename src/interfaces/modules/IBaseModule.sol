// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

interface IBaseModule {
    function getStorageAt(bytes32 slot) external pure returns (StorageSlot.Bytes32Slot memory);
}
