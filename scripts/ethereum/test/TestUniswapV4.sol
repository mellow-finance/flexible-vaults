// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAllowanceTransfer, IPositionManagerV4} from "../../common/interfaces/IPositionManagerV4.sol";

import "../../common/libraries/LiquidityAmounts.sol";
import {PositionInfoLibrary} from "../../common/libraries/PositionInfoLibrary.sol";

import {StateLibrary} from "../../common/libraries/StateLibrary.sol";
import {TickMath} from "../../common/libraries/TickMath.sol";
import "../Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Script} from "forge-std/Script.sol";
import "forge-std/Test.sol";

contract Mock is Script {
    using SafeERC20 for IERC20;

    function approves() internal {
        address this_ = address(this);
        address permit2 = IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).permit2();
        IERC20(Constants.USDC).safeIncreaseAllowance(permit2, IERC20(Constants.USDC).balanceOf(this_));
        IERC20(Constants.USDT).safeIncreaseAllowance(permit2, IERC20(Constants.USDT).balanceOf(this_));
        IAllowanceTransfer(permit2).approve(
            Constants.USDC, Constants.UNISWAP_V4_POSITION_MANAGER, type(uint160).max, uint48(block.timestamp + 365 days)
        );
        IAllowanceTransfer(permit2).approve(
            Constants.USDT, Constants.UNISWAP_V4_POSITION_MANAGER, type(uint160).max, uint48(block.timestamp + 365 days)
        );
    }

    function mint() external returns (uint256 tokenId) {
        approves();
        address this_ = address(this);
        tokenId = IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).nextTokenId();
        IPositionManagerV4.PoolKey memory poolKey = IPositionManagerV4.PoolKey({
            currency0: Constants.USDC,
            currency1: Constants.USDT,
            fee: 10,
            tickSpacing: 1,
            hooks: address(0)
        });

        // https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/Actions.sol
        bytes memory actions = abi.encodePacked(uint8(0x02), uint8(0x0d)); // mint, settle
        bytes[] memory params = new bytes[](2);

        // https://github.com/Uniswap/v4-periphery/blob/3779387e5d296f39df543d23524b050f89a62917/src/PositionManager.sol#L214-L221
        // poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData
        params[0] = abi.encode(poolKey, -10, 10, 1e6, 1e6, 1e6, this_, ""); // mint params
        params[1] = abi.encode(Constants.USDC, Constants.USDT); // settle params

        IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params), block.timestamp + 1 hours
        );

        IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).balanceOf(this_);
        require(IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).ownerOf(tokenId) == this_, "Not owner");
    }

    function increaseLiquidity(uint256 tokenId) external {
        approves();
        bytes memory actions = abi.encodePacked(uint8(0x00), uint8(0x0d)); // increase, settle
        bytes[] memory params = new bytes[](2);

        // tokenId, liquidity, amount0Max, amount1Max, hookData
        params[0] = abi.encode(tokenId, 1e6, 1e6, 1e6, ""); // increaseLiquidity params
        params[1] = abi.encode(Constants.USDC, Constants.USDT); // settle params

        IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params), block.timestamp + 1 hours
        );
        console2.logBytes(abi.encode(actions, params));
    }

    function decreaseLiquidity(uint256 tokenId) external {
        approves();
        address this_ = address(this);
        bytes memory actions = abi.encodePacked(uint8(0x01), uint8(0x11)); // decrease, take
        bytes[] memory params = new bytes[](2);

        // tokenId, liquidity, amount0Min, amount1Min, hookData
        params[0] = abi.encode(tokenId, 1e6, 0, 0, ""); // decreaseLiquidity params
        // token0, token1, recipient
        params[1] = abi.encode(Constants.USDC, Constants.USDT, this_); // take params

        IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params), block.timestamp + 1 hours
        );
    }

    /// @dev the same as decreaseLiquidity but with zero liquidity to just collect fees
    function collect(uint256 tokenId) external {
        approves();
        address this_ = address(this);
        bytes memory actions = abi.encodePacked(uint8(0x01), uint8(0x11)); // decrease, take
        bytes[] memory params = new bytes[](2);

        // tokenId, liquidity, amount0Min, amount1Min, hookData
        params[0] = abi.encode(tokenId, 0, 0, 0, ""); // decreaseLiquidity params
        // token0, token1, recipient
        params[1] = abi.encode(Constants.USDC, Constants.USDT, this_); // take params

        IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params), block.timestamp + 1 hours
        );
    }

    function getIncreaseLiquidityUnlockData(uint256 tokenId, uint256 amount0Max, uint256 amount1Max)
        public
        view
        returns (bytes memory)
    {
        (IPositionManagerV4.PoolKey memory poolKey, uint256 info) =
            IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).getPoolAndPositionInfo(tokenId);
        (uint160 sqrtRatioX96,,,) = StateLibrary.getSlot0(
            IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).poolManager(), StateLibrary.toId(poolKey)
        );

        bytes[] memory params = new bytes[](2);
        bytes memory actions = abi.encodePacked(uint8(0x00), uint8(0x0d)); // increase, settle

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(PositionInfoLibrary.tickLower(info));
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(PositionInfoLibrary.tickUpper(info));

        uint128 liquidity = LiquidityAmounts.getMaxLiquidityForAmounts(
            sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0Max, amount1Max
        );

        // tokenId, liquidity, amount0Max, amount1Max, hookData
        params[0] = abi.encode(tokenId, liquidity * 9 / 10, amount0Max, amount1Max, ""); // increaseLiquidity params
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1); // settle params

        return abi.encode(actions, params);
    }
}

contract TestUniswapV4 is Script {
    using SafeERC20 for IERC20;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address user = vm.addr(deployerPk);
        vm.startPrank(user);
        Mock mock = new Mock();
        //console2.logBytes(mock.getIncreaseLiquidityUnlockData(143331, 1e6, 1e6));
        //revert("ok");

        IERC20(Constants.USDC).safeTransfer(address(mock), IERC20(Constants.USDC).balanceOf(user));
        IERC20(Constants.USDT).safeTransfer(address(mock), IERC20(Constants.USDT).balanceOf(user));
        uint256 tokenId = mock.mint();
        mock.increaseLiquidity(tokenId);
        mock.decreaseLiquidity(tokenId);
        mock.collect(tokenId);
        vm.stopPrank();
    }
}
