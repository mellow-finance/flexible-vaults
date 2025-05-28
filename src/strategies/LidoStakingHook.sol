// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "./DepositHook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract LidoStakingHook is DepositHook {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function hook(address asset, uint256 assets)
        external
        override
        onlyDelegateCall
        returns (address, uint256)
    {
        uint256 balance = IERC20(WSTETH).balanceOf(address(this));
        if (asset == WETH) {
            IWETH(WETH).withdraw(assets);
            asset = ETH;
        }
        if (asset == ETH) {
            Address.sendValue(payable(WSTETH), assets);
        } else if (asset == STETH) {
            IERC20(STETH).approve(WSTETH, assets);
            IWSTETH(WSTETH).wrap(assets);
        } else {
            revert("StakingHook: unsupported asset");
        }
        balance = IERC20(WSTETH).balanceOf(address(this)) - balance;
        return (WSTETH, balance);
    }
}
