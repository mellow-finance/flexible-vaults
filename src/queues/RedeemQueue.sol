// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../libraries/TransferLibrary.sol";
import "../modules/RedeemModule.sol";
import "./Queue.sol";

contract RedeemQueue is Queue, ReentrancyGuardUpgradeable {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using Checkpoints for Checkpoints.Trace208;

    struct Request {
        uint256 timestamp;
        uint256 shares;
        bool isClaimable;
        uint256 assets;
    }

    struct Pair {
        uint256 assets;
        uint256 shares;
    }

    struct RedeemQueueStorage {
        uint256 handledIndices;
        uint256 outflowDemandIterator;
        mapping(address account => EnumerableMap.UintToUintMap) requestsOf;
        mapping(uint256 index => uint256 cumulativeShares) prefixSum;
        Pair[] outflowDemand;
        Checkpoints.Trace208 prices;
    }

    bytes32 private immutable _redeemQueueStorageSlot;

    constructor(string memory name_, uint256 version_) Queue(name_, version_) {
        _redeemQueueStorageSlot = SlotLibrary.getSlot("RedeemQueue", name_, version_);
    }

    // View functions

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
        uint256 outflowDemandIterator = $.outflowDemandIterator;
        (, uint48 latestEligibleTimestamp,) = $.prices.latestCheckpoint();
        Pair memory pair;
        for (uint256 i = 0; i < limit; i++) {
            (uint256 timestamp, uint256 shares) = callerRequests.at(i + offset);
            requests[i].timestamp = timestamp;
            requests[i].shares = shares;
            if (timestamp > latestEligibleTimestamp) {
                continue;
            }
            uint256 index = $.prices.lowerLookup(uint48(timestamp));
            pair = $.outflowDemand[index];
            requests[i].assets = Math.mulDiv(shares, pair.assets, pair.shares);
            requests[i].isClaimable = index < outflowDemandIterator;
        }
    }

    // Mutable functions

    receive() external payable {}

    function initialize(bytes calldata data) external initializer {
        __ReentrancyGuard_init();
        (address asset_, address sharesModule_) = abi.decode(data, (address, address));
        __Queue_init(asset_, sharesModule_);
    }

    function redeem(uint256 shares) external nonReentrant {
        if (shares == 0) {
            revert("RedeemQueue: zero shares");
        }
        address caller = _msgSender();
        SharesManager sharesManager_ = sharesManager();
        sharesManager_.pullShares(caller, shares);

        RedeemQueueStorage storage $ = _redeemQueueStorage();

        uint256 timestamp = block.timestamp;
        uint256 index;
        Checkpoints.Trace208 storage timestamps = _timestamps();
        uint208 latestTimestamp = timestamps.latest();
        if (latestTimestamp < timestamp) {
            index = timestamps.length();
            timestamps.push(uint48(timestamp), uint208(index));
            $.prefixSum[index] = shares + $.prefixSum[index - 1];
        } else {
            index = timestamps.length() - 1;
            $.prefixSum[index] += shares;
        }

        EnumerableMap.UintToUintMap storage callerRequests = $.requestsOf[caller];
        (, uint256 pendingShares) = callerRequests.tryGet(timestamp);
        callerRequests.set(timestamp, pendingShares + shares);
    }

    function claim(address account, uint256[] calldata timestamps) external nonReentrant returns (uint256 assets) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        EnumerableMap.UintToUintMap storage callerRequests = $.requestsOf[account];
        (bool doesExist, uint48 latestReportTimestamp,) = $.prices.latestCheckpoint();
        if (!doesExist) {
            return 0;
        }

        for (uint256 i = 0; i < timestamps.length; i++) {
            uint256 timestamp = timestamps[i];
            if (timestamp > latestReportTimestamp) {
                continue;
            }
            (bool hasRequest, uint256 shares) = callerRequests.tryGet(timestamp);
            if (!hasRequest || shares == 0) {
                continue;
            }
            uint256 index = $.prices.lowerLookup(uint48(timestamp));
            Pair storage pair = $.outflowDemand[index];

            uint256 assets_ = Math.mulDiv(shares, pair.assets, pair.shares);
            assets += assets_;
            pair.assets -= assets_;
            pair.shares -= shares;

            callerRequests.remove(timestamp);
        }

        TransferLibrary.sendAssets(asset(), account, assets);
    }

    /// @dev permissionless function
    function handleReports(uint256 reports) external nonReentrant returns (uint256 counter) {
        RedeemQueueStorage storage $ = _redeemQueueStorage();
        uint256 iterator_ = $.outflowDemandIterator;
        uint256 length = $.outflowDemand.length;
        if (iterator_ >= length || reports == 0) {
            return 0;
        }
        reports = Math.min(reports, length - iterator_);

        RedeemModule vault_ = RedeemModule(payable(vault()));
        address asset_ = asset();
        uint256 liquidAssets = vault_.getLiquidAssets(asset_);
        uint256 demand = 0;
        Pair memory pair;
        for (uint256 i = 0; i < reports; i++) {
            pair = $.outflowDemand[iterator_ + i];
            if (demand + pair.assets > liquidAssets) {
                break;
            }
            demand += pair.assets;
            counter++;
        }

        if (counter > 0) {
            if (demand > 0) {
                vault_.callRedeemHook(asset_, demand);
            }
            $.outflowDemandIterator += counter;
        }
    }

    // Internal functions

    function _handleReport(uint208 priceD18, uint48 latestEligibleTimestamp) internal override {
        RedeemQueueStorage storage $ = _redeemQueueStorage();

        Checkpoints.Trace208 storage timestamps = _timestamps();
        (bool exists, uint48 latestTimestamp, uint208 latestIndex) = timestamps.latestCheckpoint();
        if (!exists) {
            return;
        }

        uint256 latestEligibleIndex;
        if (latestTimestamp <= latestEligibleTimestamp) {
            latestEligibleIndex = latestIndex;
        } else {
            latestEligibleIndex = uint256(timestamps.upperLookupRecent(latestEligibleTimestamp));
            if (latestEligibleIndex == 0) {
                return;
            }
            latestEligibleIndex--;
        }

        uint256 handledIndices_ = $.handledIndices;
        if (latestEligibleIndex < handledIndices_) {
            return;
        }

        uint256 shares = $.prefixSum[latestEligibleIndex] - handledIndices_ == 0 ? 0 : $.prefixSum[handledIndices_ - 1];
        $.handledIndices = latestEligibleIndex + 1;

        if (shares == 0) {
            return;
        }

        uint256 index = $.prices.length();
        $.prices.push(latestEligibleTimestamp, uint208(index));
        $.outflowDemand.push(Pair(Math.mulDiv(shares, priceD18, 1 ether), shares));

        sharesManager().burnShares(address(this), shares);
    }

    function _redeemQueueStorage() internal view returns (RedeemQueueStorage storage $) {
        bytes32 slot = _redeemQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
