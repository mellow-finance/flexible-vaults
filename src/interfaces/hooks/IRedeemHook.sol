// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title IRedeemHook
/// @notice Interface for hooks invoked during the redeem process.
/// @dev Enables custom logic (e.g., unlocking funds, preparing liquidity) before redemptions finalize.
interface IRedeemHook {
    /// @notice Called before a redeem operation to allow preparatory logic (e.g., unwrapping, unstaking, unlocking).
    /// @param asset The address of the asset being redeemed.
    /// @param assets The amount of the asset requested for redemption.
    function beforeRedeem(address asset, uint256 assets) external;

    /// @notice Returns the currently available liquid amount of a given asset.
    /// @dev This is typically used to determine whether a redeem request can be immediately fulfilled.
    /// @param asset The address of the asset to check.
    /// @return assets The amount of the asset currently liquid and available.
    function getLiquidAssets(address asset) external view returns (uint256 assets);
}
