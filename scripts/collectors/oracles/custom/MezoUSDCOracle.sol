// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../ICustomPriceOracle.sol";

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IPyth {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    struct PriceFeed {
        bytes32 id;
        Price price;
        Price emaPrice;
    }

    function queryPriceFeed(bytes32 id) external view returns (PriceFeed memory priceFeed);
}

/// @notice mUSDC/BTC price oracle for Mezo (mUSDC = bridged USDC on Mezo).
/// priceX96 = (USDC/USD) / (BTC/USD) * 2^96
/// BTC/USD: Mezo Skip oracle (Chainlink-compatible, 18 decimals)
/// USDC/USD: Mezo Pyth oracle (8 decimals, expo = -8)
contract MezoUSDCOracle is ICustomPriceOracle {
    address private constant SKIP_BTC_USD = 0x7b7c000000000000000000000000000000000015;
    address private constant PYTH = 0x2880aB155794e7179c9eE2e38200202908C17B43;
    bytes32 private constant USDC_USD_FEED_ID = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;

    function priceX96() external view returns (uint256) {
        (, int256 btcPrice,,,) = IAggregatorV3(SKIP_BTC_USD).latestRoundData(); // 18 decimals
        IPyth.PriceFeed memory feed = IPyth(PYTH).queryPriceFeed(USDC_USD_FEED_ID);
        uint256 usdcPrice = uint256(uint64(feed.price.price)); // 8 decimals
        return Math.mulDiv(2 ** 96, usdcPrice * 1e22, uint256(btcPrice)); // mUSDC has 6 decimals vs 18 for native BTC
    }
}
