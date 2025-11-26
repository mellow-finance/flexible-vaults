// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IQueue.sol";

/// @title ISyncDepositQueue
/// @notice Interface for synchronous deposit queues that manage instant deposit requests.
/// @dev Implements instant deposit requests with no delay or oracle-based pricing.
///
/// # Overview
/// A `SyncDepositQueue` manages deposits for a specific asset with no delay.
/// Assets are deposited instantly and converted into vault shares at the latest (non-suspicious) oracle price.
/// 
interface ISyncDepositQueue is IQueue {
    /// @notice Thrown when a user is not allowed to deposit.
    error DepositNotAllowed();

    /// @notice Submits a new deposit request into the queue.
    /// @dev Reverts if a previous pending (not yet claimable) request exists.
    /// @param assets Amount of assets to deposit.
    /// @param referral Optional referral address.
    /// @param merkleProof Merkle proof for whitelist validation, if required.
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    /// @notice Always returns false.
    /// @dev Included for compatibility with queue interfaces that support claim functionality. No claims are processed by this queue.
    /// @return success Always returns false.
    function claim(address) external returns (bool success);

    /// @notice Emitted when a new deposit is made.
    /// @param account The depositor's address.
    /// @param referral Optional referral address.
    /// @param assets Amount of assets deposited.
    event Deposited(address indexed account, address indexed referral, uint224 assets);
}
