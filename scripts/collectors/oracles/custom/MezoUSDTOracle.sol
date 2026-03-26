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

/// @notice mUSDT/BTC price oracle for Mezo (mUSDT = bridged USDT on Mezo).
/// priceX96 = (USDT/USD) / (BTC/USD) * 2^96
/// BTC/USD: Mezo Skip oracle (Chainlink-compatible, 8 decimals)
/// USDT/USD: Mezo Pyth oracle (8 decimals, expo = -8)
contract MezoUSDTOracle is ICustomPriceOracle {
    address private constant SKIP_BTC_USD = 0x7b7c000000000000000000000000000000000015;
    address private constant PYTH = 0x2880aB155794e7179c9eE2e38200202908C17B43;
    bytes32 private constant USDT_USD_FEED_ID = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;

    function priceX96() external view returns (uint256) {
        (, int256 btcPrice,,,) = IAggregatorV3(SKIP_BTC_USD).latestRoundData(); // 8 decimals
        IPyth.PriceFeed memory feed = IPyth(PYTH).queryPriceFeed(USDT_USD_FEED_ID);
        uint256 usdtPrice = uint256(uint64(feed.price.price)); // 8 decimals
        return Math.mulDiv(2 ** 96, usdtPrice * 1e22, uint256(btcPrice)); // mUSDT has 6 decimals vs 18 for native BTC
    }
}
