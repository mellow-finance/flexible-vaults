// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IHook.sol";

interface IRedeemHook is IHook {
    function getLiquidAssets(address asset) external view returns (uint256 assets);
}
