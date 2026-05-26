// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IHook} from "../interfaces/hooks/IHook.sol";
import {IDepositHookStrategy} from "../interfaces/strategies/IDepositHookStrategy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract StrategyDepositHook is IHook {
    address public immutable prevHook;
    address public immutable strategy;

    constructor(address prevHook_, address strategy_) {
        prevHook = prevHook_;
        strategy = strategy_;
    }

    function callHook(address asset, uint256 assets) public virtual {
        if (prevHook != address(0)) {
            Address.functionDelegateCall(prevHook, abi.encodeCall(IHook.callHook, (asset, assets)));
        }
        Address.functionCall(
            strategy, abi.encodeCall(IDepositHookStrategy.pushDeposit, (asset, assets, address(this), prevHook))
        );
    }
}
