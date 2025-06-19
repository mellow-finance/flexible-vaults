// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISharesModule.sol";
import "../interfaces/queues/IQueue.sol";

import "../libraries/SlotLibrary.sol";

abstract contract Queue is IQueue, ContextUpgradeable, ReentrancyGuardUpgradeable {
    using Checkpoints for Checkpoints.Trace224;

    bytes32 private immutable _queueStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _disableInitializers();
        _queueStorageSlot = SlotLibrary.getSlot("Queue", name_, version_);
    }

    // View functions

    function vault() public view returns (address) {
        return _queueStorage().vault;
    }

    function sharesManager() public view returns (address) {
        return address(ISharesModule(vault()).sharesManager());
    }

    function asset() public view returns (address) {
        return _queueStorage().asset;
    }

    // Mutable functions

    function handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) external {
        if (_msgSender() != vault()) {
            revert("Queue: forbidden");
        }
        if (priceD18 == 0 || latestEligibleTimestamp >= block.timestamp) {
            revert("Queue: inalid report");
        }
        _handleReport(priceD18, latestEligibleTimestamp);
    }

    // Internal functions

    function __Queue_init(address asset_, address vault_) internal onlyInitializing {
        if (asset_ == address(0) || vault_ == address(0)) {
            revert("Queue: zero address");
        }
        QueueStorage storage $ = _queueStorage();
        $.asset = asset_;
        $.vault = vault_;
        $.timestamps.push(uint32(block.timestamp), uint224(0));
    }

    function _timestamps() internal view returns (Checkpoints.Trace224 storage) {
        return _queueStorage().timestamps;
    }

    function _queueStorage() private view returns (QueueStorage storage qs) {
        bytes32 slot = _queueStorageSlot;
        assembly {
            qs.slot := slot
        }
    }

    function _handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) internal virtual;
}
