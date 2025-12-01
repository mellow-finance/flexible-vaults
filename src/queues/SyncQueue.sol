// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISyncQueue.sol";
import "../libraries/SlotLibrary.sol";

abstract contract SyncQueue is ISyncQueue, ReentrancyGuardUpgradeable, ContextUpgradeable {
    bytes32 private immutable _syncQueueStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _syncQueueStorageSlot = SlotLibrary.getSlot("SyncQueue", name_, version_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc ISyncQueue
    function canBeRemoved() external pure returns (bool) {
        return true;
    }

    /// @inheritdoc ISyncQueue
    function vault() public view returns (address) {
        return _syncQueueStorage().vault;
    }

    /// @inheritdoc ISyncQueue
    function asset() public view returns (address) {
        return _syncQueueStorage().asset;
    }

    /// @inheritdoc ISyncQueue
    function handleReport(uint224 priceD18, uint32 timestamp) external virtual {}

    // Internal functions

    function __SyncQueue_init(address asset_, address vault_) internal onlyInitializing {
        __ReentrancyGuard_init();
        if (asset_ == address(0) || vault_ == address(0)) {
            revert ZeroValue();
        }
        SyncQueueStorage storage $ = _syncQueueStorage();
        $.asset = asset_;
        $.vault = vault_;
    }

    function _syncQueueStorage() internal view returns (SyncQueueStorage storage $) {
        bytes32 slot = _syncQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
