// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/IRedeemQueue.sol";

import "../libraries/TransferLibrary.sol";

import "./Queue.sol";

contract RedeemQueue is IRedeemQueue, Queue {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using Checkpoints for Checkpoints.Trace224;

    bytes32 private immutable _redeemQueueStorageSlot;

    constructor(string memory name_, uint256 version_) Queue(name_, version_) {
        _redeemQueueStorageSlot = SlotLibrary.getSlot("RedeemQueue", name_, version_);
    }

    // View functions

    /// @inheritdoc IRedeemQueue
    function getState() public view returns (uint256, uint256, uint256, uint256) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        return ($.batchIterator, $.batches.length, $.totalDemandAssets, $.totalPendingShares);
    }

    /// @inheritdoc IRedeemQueue
    function batchAt(uint256 index) public view returns (uint256 assets, uint256 shares) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        if (index >= $.batches.length) {
            return (0, 0);
        }
        Pair storage pair = $.batches[index];
        return (pair.assets, pair.shares);
    }

    /// @inheritdoc IRedeemQueue
    function requestsOf(address account, uint256 offset, uint256 limit)
        public
        view
        returns (Request[] memory requests)
    {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        EnumerableMap.UintToUintMap storage callerRequests = $.requestsOf[account];
        uint256 length = callerRequests.length();
        if (length <= offset) {
            return new Request[](0);
        }
        limit = Math.min(length - offset, limit);
        requests = new Request[](limit);
        uint256 batchIterator = $.batchIterator;
        (, uint32 latestEligibleTimestamp,) = $.prices.latestCheckpoint();
        Pair memory pair;
        for (uint256 i = 0; i < limit; i++) {
            (uint256 timestamp, uint256 shares) = callerRequests.at(i + offset);
            requests[i].timestamp = timestamp;
            requests[i].shares = shares;
            if (timestamp > latestEligibleTimestamp) {
                continue;
            }
            uint256 index = $.prices.lowerLookup(uint32(timestamp));
            pair = $.batches[index];
            requests[i].assets = Math.mulDiv(shares, pair.assets, pair.shares);
            requests[i].isClaimable = index < batchIterator;
        }
    }

    /// @inheritdoc IQueue
    function canBeRemoved() external view returns (bool) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        return _timestamps().length() == $.handledIndices && $.batchIterator == $.batches.length;
    }

    // Mutable functions

    receive() external payable {}

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_,) = abi.decode(data, (address, address, bytes));
        __Queue_init(asset_, shareModule_);
        emit Initialized(data);
    }

    /// @inheritdoc IRedeemQueue
    function redeem(uint256 shares) external nonReentrant {
        if (shares == 0) {
            revert ZeroValue();
        }
        address caller = _msgSender();

        address vault_ = vault();
        if (IShareModule(vault_).isPausedQueue(address(this))) {
            revert QueuePaused();
        }
        IShareManager shareManager_ = IShareManager(IShareModule(vault_).shareManager());
        shareManager_.burn(caller, shares);
        {
            IFeeManager feeManager = IShareModule(vault_).feeManager();
            uint256 fees = feeManager.calculateRedeemFee(shares);
            if (fees > 0) {
                shareManager_.mint(feeManager.feeRecipient(), fees);
                shares -= fees;
            }
        }

        RedeemQueueStorage storage $ = _redeemQueueStorage();
        uint32 timestamp = uint32(block.timestamp);
        Checkpoints.Trace224 storage timestamps = _timestamps();
        uint256 index = timestamps.length();
        (, uint32 latestTimestamp,) = timestamps.latestCheckpoint();
        if (latestTimestamp < timestamp) {
            timestamps.push(timestamp, uint224(index));
            $.prefixSum[index] = shares + $.prefixSum[index - 1];
        } else {
            $.prefixSum[--index] += shares;
        }

        EnumerableMap.UintToUintMap storage callerRequests = $.requestsOf[caller];
        (, uint256 pendingShares) = callerRequests.tryGet(timestamp);
        callerRequests.set(timestamp, pendingShares + shares);
        $.totalPendingShares += shares;
        emit RedeemRequested(caller, shares, timestamp);
    }

    /// @inheritdoc IRedeemQueue
    function claim(address receiver, uint32[] calldata timestamps) external nonReentrant returns (uint256 assets) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        address account = _msgSender();
        EnumerableMap.UintToUintMap storage callerRequests = $.requestsOf[account];
        (, uint32 latestReportTimestamp,) = $.prices.latestCheckpoint();
        if (latestReportTimestamp == 0) {
            return 0;
        }

        uint256 batchIterator = $.batchIterator;
        for (uint256 i = 0; i < timestamps.length; i++) {
            uint32 timestamp = timestamps[i];
            if (timestamp > latestReportTimestamp) {
                continue;
            }
            (bool hasRequest, uint256 shares) = callerRequests.tryGet(timestamp);
            if (!hasRequest) {
                continue;
            }
            if (shares != 0) {
                uint256 index = $.prices.lowerLookup(timestamp);
                if (index >= batchIterator) {
                    continue;
                }
                Pair storage pair = $.batches[index];

                uint256 assets_ = Math.mulDiv(shares, pair.assets, pair.shares);
                assets += assets_;
                pair.assets -= assets_;
                pair.shares -= shares;
            }
            callerRequests.remove(timestamp);
        }

        TransferLibrary.sendAssets(asset(), receiver, assets);
        emit RedeemRequestClaimed(account, receiver, assets, timestamps);
    }

    /// @inheritdoc IRedeemQueue
    function handleReports(uint256 reports) external nonReentrant returns (uint256 counter) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        uint256 iterator_ = $.batchIterator;
        uint256 length = $.batches.length;
        if (iterator_ >= length || reports == 0) {
            return 0;
        }
        reports = Math.min(reports, length - iterator_);

        IShareModule vault_ = IShareModule(vault());
        uint256 liquidAssets = vault_.getLiquidAssets();
        uint256 demand = 0;
        uint256 shares = 0;
        Pair memory pair;
        for (uint256 i = 0; i < reports; i++) {
            pair = $.batches[iterator_ + i];
            if (demand + pair.assets > liquidAssets) {
                break;
            }
            demand += pair.assets;
            shares += pair.shares;
            counter++;
        }

        if (counter > 0) {
            if (demand > 0) {
                vault_.callHook(demand);
                IVaultModule(address(vault_)).riskManager().modifyVaultBalance(asset(), -int256(uint256(demand)));
                $.totalDemandAssets -= demand;
            }
            $.batchIterator += counter;
            $.totalPendingShares -= shares;
            emit RedeemRequestsHandled(counter, demand);
        }
    }

    // Internal functions

    function _handleReport(uint224 priceD18, uint32 timestamp) internal override {
        RedeemQueueStorage storage $ = _redeemQueueStorage();

        Checkpoints.Trace224 storage timestamps = _timestamps();
        (, uint32 latestTimestamp, uint224 latestIndex) = timestamps.latestCheckpoint();
        uint256 latestEligibleIndex;
        if (latestTimestamp <= timestamp) {
            latestEligibleIndex = latestIndex;
        } else {
            latestEligibleIndex = uint256(timestamps.upperLookupRecent(timestamp));
            if (latestEligibleIndex == 0) {
                return;
            }
            latestEligibleIndex--;
        }

        uint256 handledIndices_ = $.handledIndices;
        if (latestEligibleIndex < handledIndices_) {
            return;
        }

        uint256 shares =
            $.prefixSum[latestEligibleIndex] - (handledIndices_ == 0 ? 0 : $.prefixSum[handledIndices_ - 1]);
        $.handledIndices = latestEligibleIndex + 1;

        if (shares == 0) {
            return;
        }

        uint256 index = $.prices.length();
        $.prices.push(timestamp, uint224(index));
        uint256 assets_ = Math.mulDiv(shares, 1 ether, priceD18);
        $.batches.push(Pair(assets_, shares));
        $.totalDemandAssets += assets_;
    }

    function _redeemQueueStorage() internal view returns (RedeemQueueStorage storage $) {
        bytes32 slot = _redeemQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
