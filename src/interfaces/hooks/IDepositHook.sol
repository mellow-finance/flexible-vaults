// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IDepositHook {
    function afterDeposit(address vault, address asset, uint256 assets) external;
}
