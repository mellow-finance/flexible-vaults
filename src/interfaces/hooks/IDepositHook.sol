// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title IDepositHook
/// @notice Interface for hooks executed after a deposit occurs.
/// @dev Useful for extending deposit behavior with custom logic (e.g., staking, accounting, events).
interface IDepositHook {
    /// @notice Called after a deposit has been processed by the queue.
    /// @param asset The address of the asset that was deposited.
    /// @param assets The amount of the asset deposited.
    function afterDeposit(address asset, uint256 assets) external;
}
