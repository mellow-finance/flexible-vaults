// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IHook.sol";

/// @title IRedeemHook
/// @notice Interface for redeem-side hooks that implement custom logic during asset redemptions.
interface IRedeemHook is IHook {
    /// @notice Returns the amount of liquid (immediately withdrawable) assets available for a given token.
    /// @dev Used by queues to determine how much can be processed in the current redemption cycle.
    /// @param asset The address of the ERC20 asset to check.
    /// @return assets The amount of the asset that is liquid and available.
    function getLiquidAssets(address asset) external view returns (uint256 assets);
}
