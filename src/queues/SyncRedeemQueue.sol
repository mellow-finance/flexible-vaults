// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISyncRedeemQueue.sol";

import {SlotLibrary} from "../libraries/SlotLibrary.sol";
import {TransferLibrary} from "../libraries/TransferLibrary.sol";

import "./SyncQueue.sol";

contract SyncRedeemQueue is ISyncRedeemQueue, SyncQueue {
    bytes32 private immutable _syncRedeemQueueStorageSlot;

    /// @inheritdoc ISyncRedeemQueue
    bytes32 public constant SET_SYNC_REDEEM_PARAMS_ROLE =
        keccak256("queues.SyncRedeemQueue.SET_SYNC_REDEEM_PARAMS_ROLE");

    constructor(string memory name_, uint256 version_) SyncQueue(name_, version_) {
        _syncRedeemQueueStorageSlot = SlotLibrary.getSlot("SyncRedeemQueue", name_, version_);
    }

    // View functions

    /// @inheritdoc ISyncQueue
    function name() external pure override returns (string memory) {
        return "SyncRedeemQueue";
    }

    /// @inheritdoc ISyncRedeemQueue
    function syncRedeemParams()
        external
        view
        returns (uint256 penaltyD6, uint32 maxAge, uint256 usage, uint256 dailyLimit, uint256 latestRequestTimestamp)
    {
        SyncRedeemQueueStorage storage $ = _syncRedeemQueueStorage();
        return ($.penaltyD6, $.maxAge, $.usage, $.dailyLimit, $.latestRequestTimestamp);
    }

    /// @inheritdoc ISyncRedeemQueue
    function remainingDailyLimit() public view returns (uint256 usage, uint256 remainingDailyLimit_) {
        SyncRedeemQueueStorage storage $ = _syncRedeemQueueStorage();
        uint256 dailyLimit = $.dailyLimit;
        usage = $.usage;

        uint256 timespan = block.timestamp - $.latestRequestTimestamp;
        if (timespan > 0) {
            usage = Math.saturatingSub(usage, Math.mulDiv(dailyLimit, timespan, 24 hours));
        }
        remainingDailyLimit_ = Math.saturatingSub(dailyLimit, usage);
    }

    /// @inheritdoc ISyncRedeemQueue
    function getLiquidAssets() external view returns (uint256) {
        return IShareModule(vault()).getLiquidAssets();
    }

    // Mutable functions

    receive() external payable {}

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_, bytes memory data_) = abi.decode(data, (address, address, bytes));
        __SyncQueue_init(asset_, shareModule_);
        (uint256 penaltyD6, uint32 maxAge, uint256 dailyLimit) = abi.decode(data_, (uint256, uint32, uint256));
        _setSyncRedeemParams(penaltyD6, maxAge, dailyLimit);
        emit Initialized(data);
    }

    /// @inheritdoc ISyncRedeemQueue
    function setSyncRedeemParams(uint256 penaltyD6, uint32 maxAge, uint256 dailyLimit) external {
        if (!IAccessControl(vault()).hasRole(SET_SYNC_REDEEM_PARAMS_ROLE, _msgSender())) {
            revert Forbidden();
        }
        _setSyncRedeemParams(penaltyD6, maxAge, dailyLimit);
    }

    /// @inheritdoc ISyncRedeemQueue
    function redeem(uint256 shares, address receiver) external nonReentrant {
        if (shares == 0 || receiver == address(0)) {
            revert ZeroValue();
        }
        address caller = _msgSender();
        IShareModule vault_ = IShareModule(vault());
        if (vault_.isPausedQueue(address(this))) {
            revert QueuePaused();
        }

        address asset_ = asset();

        uint256 priceD18;
        SyncRedeemQueueStorage storage $ = _syncRedeemQueueStorage();
        {
            IOracle oracle = IOracle(vault_.oracle());
            IOracle.DetailedReport memory report = oracle.getReport(asset_);
            if (report.isSuspicious || report.priceD18 == 0) {
                revert InvalidReport();
            }
            if (report.timestamp + $.maxAge < block.timestamp) {
                revert StaleReport();
            }
            priceD18 = report.priceD18;
        }

        uint256 sharesToRedeem = Math.mulDiv(shares, 1e6 - $.penaltyD6, 1e6);
        IFeeManager feeManager = vault_.feeManager();
        uint256 feeShares = feeManager.calculateRedeemFee(sharesToRedeem);
        if (feeShares > 0) {
            sharesToRedeem -= feeShares;
        }

        uint256 assets = Math.mulDiv(sharesToRedeem, 1 ether, priceD18);
        if (assets == 0) {
            revert ZeroValue();
        }
        {
            uint256 liquidAssets = vault_.getLiquidAssets();
            if (assets > liquidAssets) {
                revert InsufficientAssets(assets, liquidAssets);
            }
        }

        if (shares > _syncUsage()) {
            revert DailyLimitOverflow();
        }
        $.usage += shares;

        IShareManager shareManager_ = vault_.shareManager();
        shareManager_.burn(caller, shares);
        if (feeShares != 0) {
            shareManager_.mint(feeManager.feeRecipient(), feeShares);
        }

        vault_.callHook(assets);
        TransferLibrary.sendAssets(asset_, receiver, assets);
        IVaultModule(address(vault_)).riskManager().modifyVaultBalance(asset_, -int256(assets));
        emit Redeemed(caller, shares, assets, feeShares);
    }

    // Internal functions

    function _syncUsage() internal returns (uint256) {
        (uint256 usage_, uint256 remainingDailyLimit_) = remainingDailyLimit();
        SyncRedeemQueueStorage storage $ = _syncRedeemQueueStorage();
        $.usage = usage_;
        $.latestRequestTimestamp = block.timestamp;
        return remainingDailyLimit_;
    }

    function _setSyncRedeemParams(uint256 penaltyD6, uint32 maxAge, uint256 dailyLimit) internal {
        if (penaltyD6 > 5e5 || maxAge > 365 days) {
            revert TooLarge();
        }
        if (maxAge == 0) {
            revert ZeroValue();
        }
        if (dailyLimit % 24 hours != 0) {
            revert InvalidDailyLimit();
        }

        _syncUsage();

        SyncRedeemQueueStorage storage $ = _syncRedeemQueueStorage();
        $.penaltyD6 = penaltyD6;
        $.maxAge = maxAge;
        $.dailyLimit = dailyLimit;

        emit SyncRedeemParamsSet(penaltyD6, maxAge, dailyLimit);
    }

    function _syncRedeemQueueStorage() internal view returns (SyncRedeemQueueStorage storage $) {
        bytes32 slot = _syncRedeemQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
