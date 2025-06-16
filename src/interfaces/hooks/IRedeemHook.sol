// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IRedeemHook {
    function beforeRedeem(address asset, uint256 assets) external;

    function getLiquidAssets(address asset) external view returns (uint256);
}
