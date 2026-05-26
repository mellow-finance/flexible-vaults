// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IHook} from "../interfaces/hooks/IHook.sol";
import {IDepositHookStrategy} from "../interfaces/strategies/IDepositHookStrategy.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferHookStrategy is IDepositHookStrategy {
    using SafeERC20 for IERC20;

    constructor(address asset, address expectedVault, address expectedHook, address targetAddress) {

    }

    function pushDeposit(address asset_, uint256 assets_, address vault_, address prevHook_) external {
        require(prevHook_ != address(0));

    }
}
