// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISharesModule.sol";
import "../interfaces/oracles/IOracle.sol";
import "../interfaces/queues/IQueue.sol";
import "../interfaces/shares/ISharesManager.sol";

import "../libraries/SlotLibrary.sol";

import "./BaseModule.sol";

abstract contract SharesModule is ISharesModule, BaseModule {
    bytes32 private immutable _sharesModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _sharesModuleStorageSlot = SlotLibrary.getSlot("SharesModule", name_, version_);
    }

    // View functions

    function sharesManager() public view returns (ISharesManager) {
        return ISharesManager(_sharesModuleStorage().sharesManager);
    }

    function depositOracle() public view returns (IOracle) {
        return IOracle(_sharesModuleStorage().depositOracle);
    }

    function redeemOracle() public view returns (IOracle) {
        return IOracle(_sharesModuleStorage().redeemOracle);
    }

    function getDepositQueues(address /* asset */ ) public view virtual returns (address[] memory);

    function getRedeemQueues(address /* asset */ ) public view virtual returns (address[] memory);

    // Mutable functions

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external {
        address caller = _msgSender();
        SharesModuleStorage memory $ = _sharesModuleStorage();
        address depositOracle_ = $.depositOracle;
        address redeemOracle_ = $.redeemOracle;
        if (caller != redeemOracle_ && caller != depositOracle_) {
            revert("SharesModule: forbidden");
        }
        address[] memory queues = caller == depositOracle_ ? getDepositQueues(asset) : getRedeemQueues(asset);
        for (uint256 i = 0; i < queues.length; i++) {
            IQueue(queues[i]).handleReport(priceD18, latestEligibleTimestamp);
        }
    }

    // Internal functions

    function __SharesModule_init(address sharesManager_, address depositOracle_, address redeemOracle_)
        internal
        onlyInitializing
    {
        if (sharesManager_ == address(0)) {
            revert("SharesModule: zero address");
        }
        SharesModuleStorage storage $ = _sharesModuleStorage();
        $.sharesManager = sharesManager_;
        if (depositOracle_ != address(0) && depositOracle_ == redeemOracle_) {
            revert("SharesModule: deposit and redeem oracles must be different");
        }
        $.depositOracle = depositOracle_;
        $.redeemOracle = redeemOracle_;
    }

    function _sharesModuleStorage() internal view returns (SharesModuleStorage storage $) {
        bytes32 slot = _sharesModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
