// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../modules/IVaultModule.sol";
import "./IQueue.sol";

/// @title IRedeemQueue
/// @notice Interface for redeem queues that manage time-delayed share redemptions.
/// @dev Handles redemption requests, pricing via oracle reports, and batch claim processing.
interface IRedeemQueue is IQueue {
    /// @notice Redemption request data structure.
    struct Request {
        uint256 timestamp;
        /// Time of the redemption request.
        uint256 shares;
        /// Amount of shares requested for redemption.
        bool isClaimable;
        /// Whether the redemption can currently be claimed.
        uint256 assets;
    }
    /// Amount of assets (tokens) available for claiming.

    /// @notice Redemption batch with matched shares and corresponding assets.
    struct Pair {
        uint256 assets;
        /// Total value of assets for this redemption batch.
        uint256 shares;
    }
    /// Total shares redeemable for this batch.

    /// @notice Internal storage layout for redeem queue implementations.
    struct RedeemQueueStorage {
        uint256 handledIndices;
        uint256 batchIterator;
        uint256 totalDemandAssets;
        uint256 totalPendingShares;
        mapping(address => EnumerableMap.UintToUintMap) requestsOf;
        mapping(uint256 => uint256) prefixSum;
        Pair[] batches;
        Checkpoints.Trace224 prices;
    }
    /// Oracle price reports and timestamps.

    /// @notice Returns paginated redemption requests for a user.
    /// @param account Address of the user.
    /// @param offset Index to start pagination from.
    /// @param limit Maximum number of requests to return.
    /// @return requests List of redemption requests (claimable and pending).
    function requestsOf(address account, uint256 offset, uint256 limit)
        external
        view
        returns (Request[] memory requests);

    /// @notice Returns the asset and share for a redemption batch at a given index.
    /// @param batchIndex Index of the redemption batch.
    /// @return assets Total assets corresponding to this batch.
    /// @return shares Total shares redeemed in this batch.
    function batchAt(uint256 batchIndex) external view returns (uint256 assets, uint256 shares);

    /// @notice Returns the current state of the redeem queue system.
    /// @return batchIterator Current index of the batch iterator (i.e., next batch to process).
    /// @return batches Total number of recorded redemption batches.
    /// @return totalDemand Aggregate amount of redeem requests (in assets) awaiting fulfillment.
    /// @return totalPendingShares Total number of shares across all unprocessed redemption requests.
    function getState()
        external
        view
        returns (uint256 batchIterator, uint256 batches, uint256 totalDemand, uint256 totalPendingShares);

    /// @notice Initiates a new redemption by queuing shares for future asset claims.
    /// @param shares Amount of shares to redeem.
    function redeem(uint256 shares) external;

    /// @notice Claims previously processed redemptions using the provided timestamps.
    /// @param account Address of the user claiming.
    /// @param timestamps List of timestamps associated with processed redemption requests.
    /// @return assets Total amount of assets claimed.
    function claim(address account, uint32[] calldata timestamps) external returns (uint256 assets);

    /// @notice Processes oracle price reports and matches them against queued redemption batches.
    /// @param reports Maximum number of batches to process in one call.
    /// @return counter Number of processed redemption batches.
    function handleReports(uint256 reports) external returns (uint256 counter);

    /// @notice Emitted when a new redemption request is requested.
    event RedeemRequested(address indexed account, uint256 shares, uint256 timestamp);

    /// @notice Emitted when redemption is claimed by a user.
    event RedeemRequestClaimed(address indexed account, address indexed receiver, uint256 assets, uint32[] timestamps);

    /// @notice Emitted when oracle price reports are processed.
    event RedeemRequestsHandled(uint256 counter, uint256 demand);
}
