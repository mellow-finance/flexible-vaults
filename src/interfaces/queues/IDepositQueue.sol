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
/// @notice Interface for deposit queues managing time-delayed deposit requests.
/// @dev Implements queuing, cancellation, and claiming of asset deposits based on oracle reports.
interface IDepositQueue is IQueue {
    /// @notice Thrown when a user is not allowed to deposit.
    error DepositNotAllowed();

    /// @notice Thrown if a new deposit is attempted while an unclaimed request exists.
    error PendingRequestExists();

    /// @notice Thrown when trying to cancel a non-existent deposit request.
    error NoPendingRequest();

    /// @notice Thrown when a user tries to deposit again while a claimable request exists.
    error ClaimableRequestExists();

    /// @notice Internal storage layout for managing the deposit queue state.
    struct DepositQueueStorage {
        uint256 handledIndices; // Total number of processed (claimable or canceled) requests.
        mapping(address account => Checkpoints.Checkpoint224) requestOf; // Tracks individual deposit request timestamps.
        FenwickTreeLibrary.Tree requests; // Fenwick tree holding cumulative asset deposits.
        Checkpoints.Trace224 prices; // Oracle-reported asset price history for share calculation.
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
    /// @dev Reverts if a previous unclaimable request exists.
    /// @param assets Amount of assets to deposit.
    /// @param referral Optional referral address.
    /// @param merkleProof Merkle proof for whitelist validation, if required.
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    /// @notice Cancels the caller’s current pending deposit request.
    /// @dev Refunds the originally deposited assets.
    function cancelDepositRequest() external;

    /// @notice Claims shares from a fulfilled deposit request for a specific account.
    /// @param account Address for which to claim shares.
    /// @return success Boolean indicating whether a claim was processed.
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
