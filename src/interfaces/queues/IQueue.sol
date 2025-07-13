// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title IQueue
/// @notice Base interface for deposit and redeem queues.
/// @dev Provides common structure and logic for queue operations such as pricing and vault association.
interface IQueue is IFactoryEntity {
    /// @notice Reverts when a zero input value is supplied where non-zero is required.
    error ZeroValue();

    /// @notice Reverts when caller is not authorized to perform an action.
    error Forbidden();

    /// @notice Reverts when an oracle price report is invalid.
    error InvalidReport();

    /// @notice Reverts when queue interactions are restricted due to governance or ACL pause.
    error QueuePaused();

    /// @notice Storage layout for a generic queue contract (deposit or redeem).
    struct QueueStorage {
        /// @notice The asset managed by this queue (ERC20 or ETH).
        address asset;
        /// @notice The vault that this queue is connected to. Only this vault can trigger `handleReport`.
        address vault;
        /// @notice Timeline of user request checkpoints.
        /// @dev Stores a sorted series of (timestamp, value) pairs, where the meaning of `value` is defined by the specific queue implementation.
        Checkpoints.Trace224 timestamps;
    }

    /// @notice Returns the associated vault address.
    function vault() external view returns (address vault);

    /// @notice Returns the asset handled by this queue (ERC20 or ETH).
    function asset() external view returns (address asset);

    /// @notice Returns true if this queue is eligible for removal by the vault.
    /// @return removable True if the queue is safe to remove.
    function canBeRemoved() external view returns (bool removable);

    /// @notice Handles a new price report from the oracle.
    /// @dev Only callable by the vault. Validates input timestamp and price.
    /// @param priceD18 Price reported with 18 decimal precision (shares = price * assets).
    /// @param timestamp Timestamp when the report becomes effective.
    function handleReport(uint224 priceD18, uint32 timestamp) external;

    /// @notice Emitted when a price report is successfully processed by the queue.
    /// @param priceD18 Reported price in 18-decimal fixed-point format (shares = assets * price).
    /// @param timestamp All unprocessed requests with timestamps <= this value were handled using this report.
    event ReportHandled(uint224 priceD18, uint32 timestamp);
}
