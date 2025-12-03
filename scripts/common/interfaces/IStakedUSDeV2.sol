// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IStakedUSDeV2 {
    /// @notice redeem shares into assets and starts a cooldown to claim the converted underlying asset
    /// @param shares shares to redeem
    function cooldownShares(uint256 shares) external returns (uint256 assets);
}
