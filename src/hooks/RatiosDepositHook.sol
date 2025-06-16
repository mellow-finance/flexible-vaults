// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/hooks/IDepositHook.sol";

contract RatiosDepositHook is IDepositHook {
    function afterDeposit(address asset, uint256 assets) external {}
}
