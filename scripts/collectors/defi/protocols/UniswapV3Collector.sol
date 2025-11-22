// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/vaults/Vault.sol";
import "./IDistributionCollector.sol";

import "./uniswap-v3/libraries/PositionLibrary.sol";
import "./uniswap-v3/libraries/PositionValue.sol";

contract UniswapV3Collector is IDistributionCollector {
    uint16 public constant MIN_OBSERVATION_CARDINALITY = 100;

    INonfungiblePositionManager public immutable positionManager;

    constructor(address positionManager_) {
        positionManager = INonfungiblePositionManager(positionManager_);
    }

    function getDistributions(address holder, bytes calldata deployment, address[] calldata assets)
        external
        view
        returns (Balance[] memory balances)
    {
        balances = new Balance[](assets.length);
        (address[] memory whitelistedPools, bytes memory securityParams) = abi.decode(deployment, (address[], bytes));
        uint256 positions = positionManager.balanceOf(holder);
        for (uint256 i = 0; i < assets.length; i++) {
            balances[i] = Balance({asset: assets[i], balance: 0, metadata: "UniswapV3", holder: holder});
        }

        IUniswapV3Factory factory = IUniswapV3Factory(positionManager.factory());

        for (uint256 index = 0; index < positions; index++) {
            uint256 tokenId = positionManager.tokenOfOwnerByIndex(holder, index);
            PositionLibrary.Position memory position = PositionLibrary.getPosition(address(positionManager), tokenId);

            address pool = factory.getPool(position.token0, position.token1, position.fee);

            if (indexOf(whitelistedPools, pool) == type(uint256).max) {
                continue;
            }

            uint256 token0Index = indexOf(assets, position.token0);
            uint256 token1Index = indexOf(assets, position.token1);
            if (token0Index == type(uint256).max || token1Index == type(uint256).max) {
                revert("UniswapV3Collector: whitelisted pool has unsupported tokens");
            }

            uint160 sqrtPriceX96 = getCheckedPrice(IUniswapV3Pool(pool), securityParams);
            (uint256 amount0, uint256 amount1) = PositionValue.principal(positionManager, tokenId, sqrtPriceX96);
            {
                (uint256 fee0, uint256 fee1) = PositionValue.fees(positionManager, tokenId);
                amount0 += fee0;
                amount1 += fee1;
            }
            balances[token0Index].balance += int256(amount0);
            balances[token1Index].balance += int256(amount1);
        }

        uint256 iterator = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (balances[i].balance == 0) {
                continue;
            }
            balances[iterator++] = balances[i];
        }
        assembly {
            mstore(balances, iterator)
        }
    }

    function getCheckedPrice(IUniswapV3Pool pool, bytes memory securityParams)
        public
        view
        returns (uint160 sqrtPriceX96)
    {
        (uint32 timespan, int24 maxDeviation) = abi.decode(securityParams, (uint32, int24));
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = timespan;

        int24 spotTick;
        (sqrtPriceX96, spotTick,,,,,) = pool.slot0();
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
        int24 averageTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int32(timespan)));

        int24 delta = averageTick - spotTick;
        if (delta < 0) {
            delta = -delta;
        }
        if (delta > maxDeviation) {
            revert("UniswapV3Pool: delta > maxDeviation");
        }
    }

    function indexOf(address[] memory assets, address asset) public pure returns (uint256) {
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                return i;
            }
        }
        return type(uint256).max;
    }
}
