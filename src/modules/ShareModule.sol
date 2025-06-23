// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IShareManager.sol";
import "../interfaces/modules/IShareModule.sol";
import "../interfaces/oracles/IOracle.sol";
import "../interfaces/queues/IQueue.sol";

import "../libraries/SlotLibrary.sol";

import "./BaseModule.sol";

abstract contract ShareModule is IShareModule, BaseModule {
    bytes32 private immutable _shareModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _shareModuleStorageSlot = SlotLibrary.getSlot("ShareModule", name_, version_);
    }

    // View functions

    function shareManager() public view returns (IShareManager) {
        return IShareManager(_shareModuleStorage().shareManager);
    }

    function feeManager() public view returns (IFeeManager) {
        return IFeeManager(_shareModuleStorage().feeManager);
    }

    function depositOracle() public view returns (IOracle) {
        return IOracle(_shareModuleStorage().depositOracle);
    }

    function redeemOracle() public view returns (IOracle) {
        return IOracle(_shareModuleStorage().redeemOracle);
    }

    function getDepositQueues(address /* asset */ ) public view virtual returns (address[] memory);

    function getRedeemQueues(address /* asset */ ) public view virtual returns (address[] memory);

    // Mutable functions

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external {
        address caller = _msgSender();
        ShareModuleStorage memory $ = _shareModuleStorage();
        address depositOracle_ = $.depositOracle;
        address redeemOracle_ = $.redeemOracle;
        if (caller != redeemOracle_ && caller != depositOracle_) {
            revert("ShareModule: forbidden");
        }
        address[] memory queues = caller == depositOracle_ ? getDepositQueues(asset) : getRedeemQueues(asset);
        for (uint256 i = 0; i < queues.length; i++) {
            IQueue(queues[i]).handleReport(priceD18, latestEligibleTimestamp);
        }
        IFeeManager feeManager_ = feeManager();
        uint256 fees = feeManager_.calculateProtocolFee(address(this), shareManager().totalShares())
            + feeManager_.calculatePerformanceFee(address(this), asset, priceD18);
        if (fees > 0) {
            shareManager().mint(feeManager_.feeRecipient(), fees);
        }
        feeManager_.updateState(asset, priceD18);
    }

    // Internal functions

    function __ShareModule_init(
        address shareManager_,
        address feeManager_,
        address depositOracle_,
        address redeemOracle_
    ) internal onlyInitializing {
        if (
            shareManager_ == address(0) || feeManager_ == address(0) || depositOracle_ == address(0)
                || redeemOracle_ == address(0)
        ) {
            revert("ShareModule: zero address");
        }
        ShareModuleStorage storage $ = _shareModuleStorage();
        $.shareManager = shareManager_;
        $.feeManager = feeManager_;
        if (depositOracle_ == redeemOracle_) {
            revert("ShareModule: same oracles");
        }
        $.depositOracle = depositOracle_;
        $.redeemOracle = redeemOracle_;
    }

    function _shareModuleStorage() internal view returns (ShareModuleStorage storage $) {
        bytes32 slot = _shareModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
