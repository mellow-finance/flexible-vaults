// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import "../../libraries/FenwickTreeLibrary.sol";

import "../managers/IRiskManager.sol";
import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "./IQueue.sol";

/// @title IDepositQueue
/// @notice Interface for deposit queues that manage time-delayed deposit requests with oracle-based pricing.
/// @dev Implements request creation, cancellation, and oracle-based price batch processing.
///
/// # Overview
/// A `DepositQueue` manages deposits for a specific asset with a time delay enforced by an oracle (`depositInterval`). It enforces the following invariants:
/// 1. Each user may have only one pending deposit request at a time.
/// 2. Each request is defined by `(amount, timestamp)`.
/// 3. Based on oracle reports queue determines when deposit requests are processed.
///    A report handles only those requests older than a configured `depositInterval`.
///
/// Once an oracle report is submitted at `reportTimestamp`, it processes all requests with `timestamp <= reportTimestamp - depositInterval`, converting asset deposits into vault shares at the reported price.
///
/// # User Cancellation
/// Users can cancel pending deposit requests before they are processed. This ensures a binary lifecycle:
/// - Either a user has a pending request they can cancel, or
/// - The request has been executed and the user owns shares.
///
/// # Scalability Challenge
/// Vaults can receive thousands of deposit requests per day. Processing each request individually is gas-inefficient.
/// To solve this, a **Fenwick Tree** is used to maintain prefix sums of deposits per timestamp.
///
/// # Fenwick Tree Usage
/// - When a user deposits `amount` at time `T`, the system records `fenwickTree[T] += amount`.
/// - If the user cancels, then `fenwickTree[T] -= amount`.
/// - On oracle report at time `reportTimestamp`, the system calculates:
///   `fenwickTree.getSum(latestHandledTimestamp + 1, reportTimestamp - depositInterval)`
///   to determine the total amount to convert into vault shares at the reported price.
///
/// The vault uses **lazy propagation** to calculate claimable shares per user without eagerly updating all balances in the `handleReport` processing.
/// Shares become fully claimed on the next interaction (e.g., claim, transfer or new deposit).
///
/// Additionally, **timestamp compression (coordinate compression)** is used to track in FenwickTree only timestamps where actual requests were made, reducing storage overhead.
interface IDepositQueue is IQueue {
    /// @notice Thrown when a user is not allowed to deposit.
    error DepositNotAllowed();

    /// @notice Thrown if a new deposit is attempted while an pending request exists.
    error PendingRequestExists();

    /// @notice Thrown when a user tries to deposit again while a claimable request exists.
    error ClaimableRequestExists();

    /// @notice Thrown when trying to cancel a non-existent deposit request.
    error NoPendingRequest();

    /// @notice Storage layout for managing the state of a deposit queue.
    struct DepositQueueStorage {
        /// @dev Iterator representing the number of fully processed `timestamps`.
        /// Each timestamp may correspond to multiple user requests.
        uint256 handledIndices;
        /// @dev Mapping of user address to their latest deposit request.
        /// Each request is stored as a checkpoint with timestamp (key) and asset amount (value).
        mapping(address account => Checkpoints.Checkpoint224) requestOf;
        /// @dev Fenwick tree tracking cumulative asset deposits by timestamp indices.
        /// Enables efficient range sum queries and updates for oracle processing.
        FenwickTreeLibrary.Tree requests;
        /// @dev Price history reported by the oracle (indexed by timestamp).
        /// Used to convert deposited assets into vault shares.
        Checkpoints.Trace224 prices;
    }

    /// @notice Returns the number of shares that can currently be claimed by the given account.
    /// @param account Address of the user.
    /// @return shares Amount of claimable shares.
    function claimableOf(address account) external view returns (uint256 shares);

    /// @notice Retrieves the timestamp and asset amount for a user's pending deposit request.
    /// @param account Address of the user.
    /// @return timestamp When the deposit was requested.
    /// @return assets Amount of assets deposited.
    function requestOf(address account) external view returns (uint256 timestamp, uint256 assets);

    /// @notice Submits a new deposit request into the queue.
    /// @dev Reverts if a previous pending (not yet claimable) request exists.
    /// @param assets Amount of assets to deposit.
    /// @param referral Optional referral address.
    /// @param merkleProof Merkle proof for whitelist validation, if required.
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    /// @notice Cancels the caller's current pending deposit request.
    /// @dev Refunds the originally deposited assets.
    function cancelDepositRequest() external;

    /// @notice Claims shares from a fulfilled deposit request for a specific account.
    /// @param account Address for which to claim shares.
    /// @return success Boolean indicating whether a claim was successful.
    function claim(address account) external returns (bool success);

    /// @notice Emitted when a new deposit request is submitted.
    /// @param account The depositor's address.
    /// @param referral Optional referral address.
    /// @param assets Amount of assets deposited.
    /// @param timestamp Timestamp when the request was created.
    event DepositRequested(address indexed account, address indexed referral, uint224 assets, uint32 timestamp);

    /// @notice Emitted when a pending deposit request is canceled.
    /// @param account Address of the user who canceled the request.
    /// @param assets Amount of assets refunded.
    /// @param timestamp Timestamp of the original request.
    event DepositRequestCanceled(address indexed account, uint256 assets, uint32 timestamp);

    /// @notice Emitted when a deposit request is successfully claimed into shares.
    /// @param account Address receiving the shares.
    /// @param shares Number of shares claimed.
    /// @param timestamp Timestamp of the original deposit request.
    event DepositRequestClaimed(address indexed account, uint256 shares, uint32 timestamp);
}
