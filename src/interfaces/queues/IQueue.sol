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

    /// @notice Reverts when an oracle price report is malformed, invalid, or rejected.
    error InvalidReport();

    /// @notice Reverts when queue interactions are restricted due to governance or ACL pause.
    error QueuePaused();

    /// @notice Internal storage layout for a queue contract.
    struct QueueStorage {
        address asset;
        /// The asset handled by the queue (e.g., ERC20 token).
        address vault;
        /// Address of the associated vault.
        Checkpoints.Trace224 timestamps;
    }
    /// Oracle-reported price history (timestamp → price).

    /// @notice Returns the associated vault address.
    /// @return vault The address of the vault using this queue.
    function vault() external view returns (address vault);

    /// @notice Returns the asset handled by this queue (ERC20 or ETH).
    /// @return asset The address of the underlying asset.
    function asset() external view returns (address asset);

    /// @notice Returns true if this queue is eligible for removal by the vault.
    /// @dev Typically used during upgrades or vault reconfigurations.
    /// @return removable True if the queue is safe to remove.
    function canBeRemoved() external view returns (bool removable);

    /// @notice Handles a new price report from the oracle.
    /// @dev Only callable by the vault. Validates input timestamp and price.
    /// @param priceD18 Price reported with 18 decimal precision.
    /// @param timestamp Timestamp when the report becomes effective.
    function handleReport(uint224 priceD18, uint32 timestamp) external;

    /// @notice Emitted when a price report is successfully processed by the queue.
    /// @param priceD18 Reported price (18-decimal fixed-point).
    /// @param timestamp Timestamp of when the price becomes valid.
    event ReportHandled(uint224 priceD18, uint32 timestamp);
}
