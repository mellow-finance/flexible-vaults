// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IPositionManagerV4} from "./interfaces/IPositionManagerV4.sol";
import "./libraries/LiquidityAmounts.sol";
import {PositionInfoLibrary} from "./libraries/PositionInfoLibrary.sol";

import {StateLibrary} from "./libraries/StateLibrary.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UniswapV4UnlockDataGenerator {
    IPositionManagerV4 public constant POSITION_MANAGER = IPositionManagerV4(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e);
    uint256 private constant D6 = 10 ** 6;

    // https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/Actions.sol
    uint8 private constant ACTION_INCREASE_LIQUIDITY = uint8(0x00);
    uint8 private constant ACTION_DECREASE_LIQUIDITY = uint8(0x01);
    uint8 private constant ACTION_SETTLE_PAIR = uint8(0x0d);
    uint8 private constant ACTION_TAKE_PAIR = uint8(0x11);

    struct Currency {
        address addr;
        string symbol;
        uint256 amount;
    }

    struct LiquidityData {
        uint256 tokenId;
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int24 spotTick;
        uint160 sqrtRatioX96;
        uint128 liquidity;
        uint128 liquidityDelta;
        Currency currency0;
        Currency currency1;
        bytes unlockData;
    }

    /// @notice Generates unlock data for increasing liquidity in Uniswap V4 position
    function getIncreaseLiquidityUnlockData(uint256 tokenId, uint256 amount0Max, uint256 amount1Max, uint256 slippageD6)
        public
        view
        returns (LiquidityData memory data)
    {
        bytes[] memory params = new bytes[](2);
        bytes memory actions = abi.encodePacked(ACTION_INCREASE_LIQUIDITY, ACTION_SETTLE_PAIR); // increase, settle

        data = getInfo(tokenId);

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(data.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(data.tickUpper);

        /// @dev calculate liquidity delta before slippage
        data.liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(
            data.sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0Max, amount1Max
        );

        /// @dev calculate amounts before slippage
        (data.currency0.amount, data.currency1.amount) = LiquidityAmounts.getAmountsForLiquidity(
            data.sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, data.liquidityDelta
        );

        /// @dev apply slippage: reducing liquidity delta, but keeping amounts the same (to do not exceed max amounts)
        data.liquidityDelta = uint128(data.liquidityDelta * (D6 - slippageD6) / D6);

        // tokenId, liquidity, amount0Max, amount1Max, hookData
        params[0] = abi.encode(data.tokenId, data.liquidityDelta, data.currency0.amount, data.currency1.amount, ""); // increaseLiquidity params
        params[1] = abi.encode(data.currency0.addr, data.currency1.addr); // settle params

        data.unlockData = abi.encode(actions, params);
    }

    /// @notice Generates unlock data for increasing liquidity in Uniswap V4 position with custom data
    function getIncreaseLiquidityUnlockDataCustom(
        uint256 tokenId,
        uint256 amount0Max,
        uint256 amount1Max,
        uint128 liquidityDelta
    ) public view returns (LiquidityData memory data) {
        bytes[] memory params = new bytes[](2);
        bytes memory actions = abi.encodePacked(ACTION_INCREASE_LIQUIDITY, ACTION_SETTLE_PAIR); // increase, settle

        data = getInfo(tokenId);
        data.liquidityDelta = liquidityDelta;
        (data.currency0.amount, data.currency1.amount) = (amount0Max, amount1Max);
        // tokenId, liquidity, amount0Max, amount1Max, hookData
        params[0] = abi.encode(data.tokenId, liquidityDelta, amount0Max, amount1Max, ""); // increaseLiquidity params
        params[1] = abi.encode(data.currency0.addr, data.currency1.addr); // settle params

        data.unlockData = abi.encode(actions, params);
    }

    /// @notice Generates unlock data for decreasing liquidity in Uniswap V4 position
    function getDecreaseLiquidityUnlockData(
        uint256 tokenId,
        uint128 liquidityDelta,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 slippageD6,
        address recipient
    ) public view returns (LiquidityData memory data) {
        bytes memory actions = abi.encodePacked(ACTION_DECREASE_LIQUIDITY, ACTION_TAKE_PAIR); // decrease, take
        bytes[] memory params = new bytes[](2);
        data = getInfo(tokenId);

        data.liquidityDelta = liquidityDelta;

        if (data.liquidityDelta > 0) {
            /// @dev actually decrease liquidity
            if (data.liquidityDelta > data.liquidity) {
                data.liquidityDelta = data.liquidity;
            }

            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(data.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(data.tickUpper);
            /// @dev amounts with slippage
            (data.currency0.amount, data.currency1.amount) = LiquidityAmounts.getAmountsForLiquidity(
                data.sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, uint128(data.liquidityDelta * (D6 - slippageD6) / D6)
            );
        } else {
            /// @dev if liquidityDelta = 0 -> just collect fees
            (amount0Min, amount1Min) = (0, 0);
        }

        // tokenId, liquidity, amount0Min, amount1Min, hookData
        params[0] = abi.encode(tokenId, liquidityDelta, amount0Min, amount1Min, ""); // decreaseLiquidity params

        // token0, token1, recipient
        params[1] = abi.encode(data.currency0.addr, data.currency1.addr, recipient); // take params

        data.unlockData = abi.encode(actions, params);
    }

    /// @notice Generates unlock data for decreasing liquidity in Uniswap V4 position with custom data
    function getDecreaseLiquidityUnlockDataCustom(
        uint256 tokenId,
        uint128 liquidityDelta,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) public view returns (LiquidityData memory data) {
        bytes memory actions = abi.encodePacked(ACTION_DECREASE_LIQUIDITY, ACTION_TAKE_PAIR); // decrease, take
        bytes[] memory params = new bytes[](2);
        data = getInfo(tokenId);

        data.liquidityDelta = liquidityDelta;

        // tokenId, liquidity, amount0Min, amount1Min, hookData
        params[0] = abi.encode(tokenId, liquidityDelta, amount0Min, amount1Min, ""); // decreaseLiquidity params

        // token0, token1, recipient
        params[1] = abi.encode(data.currency0.addr, data.currency1.addr, recipient); // take params

        data.unlockData = abi.encode(actions, params);
    }

    /// @notice Fetches position and pool info from PositionManager
    function getInfo(uint256 tokenId) public view returns (LiquidityData memory data) {
        (IPositionManagerV4.PoolKey memory poolKey, uint256 info) = POSITION_MANAGER.getPoolAndPositionInfo(tokenId);

        (data.sqrtRatioX96,,,) = StateLibrary.getSlot0(POSITION_MANAGER.poolManager(), StateLibrary.toId(poolKey));
        data.spotTick = TickMath.getTickAtSqrtRatio(data.sqrtRatioX96);
        data.tokenId = tokenId;
        data.liquidity = POSITION_MANAGER.getPositionLiquidity(tokenId);
        data.owner = POSITION_MANAGER.ownerOf(tokenId);
        data.tickLower = PositionInfoLibrary.tickLower(info);
        data.tickUpper = PositionInfoLibrary.tickUpper(info);
        data.currency0.symbol = IERC20Metadata(poolKey.currency0).symbol();
        data.currency0.addr = poolKey.currency0;
        data.currency1.symbol = IERC20Metadata(poolKey.currency1).symbol();
        data.currency1.addr = poolKey.currency1;
    }
}
