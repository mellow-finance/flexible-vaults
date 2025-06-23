// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";

import "../libraries/TransferLibrary.sol";

import "./BasicDepositHook.sol";

contract LidoStakingHook is BasicDepositHook {
    using SafeERC20 for IERC20;

    address public immutable wsteth;
    address public immutable steth;
    address public immutable weth;

    constructor(address wsteth_, address weth_) {
        wsteth = wsteth_;
        steth = IWSTETH(wsteth_).stETH();
        weth = weth_;
    }

    function afterDeposit(address vault, address asset, uint256 assets) public override {
        if (asset != wsteth) {
            uint256 balance = IERC20(wsteth).balanceOf(vault);
            if (asset == steth) {
                IERC20(steth).safeIncreaseAllowance(wsteth, assets);
                IWSTETH(wsteth).wrap(assets);
            } else {
                if (asset == weth) {
                    IWETH(weth).withdraw(assets);
                } else if (asset != TransferLibrary.ETH) {
                    revert("LidoStakingHook: unsupported asset");
                }
                Address.sendValue(payable(wsteth), assets);
            }
            assets = IERC20(wsteth).balanceOf(vault) - balance;
        }
        super.afterDeposit(vault, wsteth, assets);
    }
}
