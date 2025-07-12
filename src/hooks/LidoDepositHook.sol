// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/external/tokens/IWETH.sol";
import "../interfaces/external/tokens/IWSTETH.sol";
import "../interfaces/hooks/IHook.sol";

import "../libraries/TransferLibrary.sol";

contract LidoDepositHook is IHook {
    error UnsupportedAsset(address asset);

    using SafeERC20 for IERC20;

    address public immutable wsteth;
    address public immutable steth;
    address public immutable weth;
    address public immutable nextHook;

    constructor(address wsteth_, address weth_, address nextHook_) {
        wsteth = wsteth_;
        steth = IWSTETH(wsteth_).stETH();
        weth = weth_;
        nextHook = nextHook_;
    }

    function callHook(address asset, uint256 assets) public override {
        if (asset != wsteth) {
            uint256 balance = IERC20(wsteth).balanceOf(address(this));
            if (asset == steth) {
                IERC20(steth).safeIncreaseAllowance(wsteth, assets);
                IWSTETH(wsteth).wrap(assets);
            } else {
                if (asset == weth) {
                    IWETH(weth).withdraw(assets);
                } else if (asset != TransferLibrary.ETH) {
                    revert UnsupportedAsset(asset);
                }
                Address.sendValue(payable(wsteth), assets);
            }
            assets = IERC20(wsteth).balanceOf(address(this)) - balance;
        }
        if (nextHook != address(0)) {
            Address.functionDelegateCall(nextHook, abi.encodeCall(IHook.callHook, (wsteth, assets)));
        }
    }
}
