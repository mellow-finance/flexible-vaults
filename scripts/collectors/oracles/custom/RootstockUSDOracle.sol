// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice USD/BTC price oracle for Rootstock.
/// priceX96 = 2^96 / (BTC/USD)
/// BTC/USD: RedStone Price Feed for BTC (Chainlink-compatible, 8 decimals).
/// The feed reverts internally once its data goes stale, so no extra staleness guard is needed here.
contract RootstockUSDOracle is ICustomPriceOracle {
    address private constant REDSTONE_BTC_USD = 0x197225B3B017eb9b72Ac356D6B3c267d0c04c57c;

    function priceX96() external view returns (uint256) {
        (, int256 btcPrice,,,) = IAggregatorV3(REDSTONE_BTC_USD).latestRoundData(); // 8 decimals
        return Math.mulDiv(2 ** 96, 1e18, uint256(btcPrice)); // USD has 8 decimals vs 18 for native RBTC
    }
}
