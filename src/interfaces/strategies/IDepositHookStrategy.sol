// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IDepositHookStrategy {
    function pushDeposit(address asset, uint256 assets, address vault, address prevHook) external;
}
