// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../modules/IVaultModule.sol";
import "./IQueue.sol";

/// @title IRedeemQueue
/// @notice Interface for redeem queues that manage time-delayed redemptions of vault shares into underlying assets.
/// @dev Handles request creation, price-based batch processing, and asynchronous liquidity settlement.
///
/// # Overview
/// A `RedeemQueue` allows users to request conversion of their vault shares into assets. It introduces a delay enforced by an oracle (`redeemInterval`), and ensures the following invariants:
/// 1. Each request is defined by `(shares, timestamp)`.
/// 2. Requests are **not cancellable**, to prevent griefing (e.g., by requesting redemption and cancelling after unstaking starts).
/// 3. Users may have multiple independent redemption requests.
///
/// Once an oracle report is submitted at `reportTimestamp`, it processes all requests with `timestamp <= reportTimestamp - redeemInterval`, converting vault shares into asset values using the reported price.
///
/// # Liquidity Processing (Two-Stage)
/// Redemption handling is decoupled from actual asset movement to allow asynchronous liquidity management:
/// - After a request is created, vault curators may pull liquidity from external protocols.
/// - Once oracle report is submitted and enough liquidity is available, vault curator (or any other actor) calls `handleReport()` on the redeem queue.
/// - This pulls required amount of assets from the Vault (and Subvaults) processing created redemption requests.
///
/// # Scalability Approach
/// Unlike deposits, redemption requests are never cancelled. This allows the system to use a **prefix sum array** to track requests over time.
///
/// # Redemption Processing
/// - When a user redeems `amount` shares at time `T`, the system records `prefixSum[T] += shares`.
/// - At oracle report time `reportTimestamp`, all requests with `timestamp <= reportTimestamp - redeemInterval` are marked as processed.
/// - Curator pushes the required assets to the queue by managin vault liquidity and calling `handleBatches` function afterwards.
/// - Users call `claim(receiver, timestamps[])` to redeem their processed shares for assets.
interface IRedeemQueue is IQueue {
    /// @notice Redemption request metadata for a user.
    /// @dev Represents a single request to convert vault shares into underlying assets.
    struct Request {
        /// @notice Timestamp when the redemption request was submitted.
        /// @dev Determines eligibility for processing based on oracle report timing and `redeemInterval`.
        uint256 timestamp;
        /// @notice Amount of vault shares submitted for redemption.
        uint256 shares;
        /// @notice Whether the request has been processed and is now claimable.
        /// @dev Set to `true` after liquidity has been allocated via `handleBatches`.
        bool isClaimable;
        /// @notice Amount of assets that can be claimed by the user.
        /// @dev Calculated and stored after a matching oracle report has been processed via `handleReport`.
        uint256 assets;
    }

    /// @notice Redemption batch result with total matched shares and corresponding assets.
    /// @dev Represents a single price batch where multiple redemption requests are settled at the same oracle-reported price.
    struct Batch {
        /// @notice Total amount of assets allocated for this redemption batch.
        /// @dev Calculated during `handleReport` using the reported price and total matched shares.
        uint256 assets;
        /// @notice Total number of vault shares handled in this batch.
        /// @dev Includes all user requests processed at the same oracle report.
        uint256 shares;
    }

    /// @notice Storage layout for the RedeemQueue contract.
    /// @dev Tracks redemption request state, oracle-based batch settlements, and pricing checkpoints.
    struct RedeemQueueStorage {
        /// @notice Number of timestamp-based redemption checkpoints that have been processed.
        /// @dev Ensures sequential handling of oracle reports.
        uint256 handledIndices;
        /// @notice Number of claimable batches.
        /// @dev Increments as batches are handled via `handleBatches` and become claimable.
        uint256 batchIterator;
        /// @notice Total amount of assets needed to fulfill all currently batched redemption requests.
        /// @dev Equals the sum of `batches[i].assets` for all indices `i` such that `batchIterator <= i < batches.length`.
        uint256 totalDemandAssets;
        /// @notice Total shares from redemption requests that are not yet claimable.
        /// @dev Increases when users create new redemption requests and decreases after they are processed via `handleBatches`.
        uint256 totalPendingShares;
        /// @notice Mapping of redemption requests per user.
        /// @dev Each user maps to a set of `(timestamp => shares)` representing open requests.
        mapping(address => EnumerableMap.UintToUintMap) requestsOf;
        /// @notice Prefix sum of requested shares grouped by timestamp.
        /// @dev Enables efficient calculation of total demand in a redemption window.
        mapping(uint256 => uint256) prefixSum;
        /// @notice Batches created from processed oracle reports.
        /// @dev Each batch maps total requested shares to the equivalent amount of assets.
        Batch[] batches;
        /// @notice Historical oracle pricing checkpoints for batch processing.
        /// @dev Associates report timestamps with their respective batch index.
        Checkpoints.Trace224 prices;
    }

    /// @notice Returns a paginated list of redemption requests for a user.
    /// @dev Returned requests can be in one of the following states:
    /// - Pending: Awaiting processing by an oracle report.
    /// - Handled: Processed by oracle report but not yet claimable (assets not yet pulled from the Vault).
    /// - Claimable: Processed and fully settled; assets are ready to be claimed.
    /// @param account Address of the user.
    /// @param offset Starting index for pagination.
    /// @param limit Maximum number of requests to return.
    /// @return requests Array of user's redemption requests with full status metadata.
    function requestsOf(address account, uint256 offset, uint256 limit)
        external
        view
        returns (Request[] memory requests);

    /// @notice Returns assets and shares for a redemption batch at a given index.
    /// @param batchIndex Index of the redemption batch.
    /// @return assets Total assets corresponding to this batch.
    /// @return shares Total shares redeemed in this batch.
    function batchAt(uint256 batchIndex) external view returns (uint256 assets, uint256 shares);

    /// @notice Returns the current state of the redeem queue system.
    /// @return batchIterator Current index of the batch iterator (i.e., next batch to process).
    /// @return batches Total number of recorded redemption batches.
    /// @return totalDemandAssets Aggregate amount of redeem requests (in assets) awaiting fulfillment.
    /// @return totalPendingShares Total number of shares across all redemption requests that are not yet claimable.
    function getState()
        external
        view
        returns (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares);

    /// @notice Initiates a new redemption by queuing shares for future asset claims.
    /// @param shares Amount of shares to redeem.
    function redeem(uint256 shares) external;

    /// @notice Claims redemption requests for a user based on the provided timestamps.
    /// @dev A request is successfully claimed only if:
    /// - The associated timestamp has been processed by an oracle report, and
    /// - The corresponding batch has been settled via `handleBatches`.
    ///
    /// The function is idempotent — requests that are already claimed or not yet eligible are skipped without reverting.
    ///
    /// @param account Address of the user claiming the redemptions.
    /// @param timestamps List of request timestamps to claim.
    /// @return assets Total amount of assets successfully claimed.
    function claim(address account, uint32[] calldata timestamps) external returns (uint256 assets);

    /// @notice Processes pending redemption batches by pulling required liquidity from the Vault.
    /// @dev This function fulfills the asset side of redemption requests that have already been priced
    ///      via oracle reports. For each processed batch:
    ///      - Assets are pulled from the Vault to the RedeemQueue contract.
    ///      - Matching shares are marked as claimable for users.
    ///
    /// This function enables asynchronous coordination between oracle reporting and vault liquidity management.
    ///
    /// @param batches Maximum number of batches to process in this call.
    /// @return counter Number of successfully processed redemption batches.
    function handleBatches(uint256 batches) external returns (uint256 counter);

    /// @notice Emitted when a new redemption request is requested.
    event RedeemRequested(address indexed account, uint256 shares, uint256 timestamp);

    /// @notice Emitted when redemption is claimed by a user.
    event RedeemRequestClaimed(address indexed account, address indexed receiver, uint256 assets, uint32 timestamp);

    /// @notice Emitted when oracle price reports are processed.
    event RedeemRequestsHandled(uint256 counter, uint256 demand);
}
