// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title IHook
/// @notice Interface for a generic hook contract used to process asset-related logic during queue execution upon oracle reports.
/// @dev This interface is intended for both deposit and redeem queues, where additional logic (e.g. wrapping, redistributions, auto-compounding,
/// liquidity checks) must be executed atomically during queue finalization. Typically called via `delegatecall`.
interface IHook {
    /// @notice Executes custom logic for the given asset and amount during queue processing.
    /// @dev This function is called via `delegatecall` by the ShareModule or Vault.
    /// @param asset The address of the ERC20 asset being processed.
    /// @param assets The amount of the asset involved in the operation.
    function callHook(address asset, uint256 assets) external;
}
