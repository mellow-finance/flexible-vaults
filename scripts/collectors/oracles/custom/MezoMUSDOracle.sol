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

/// @notice MUSD/BTC price oracle for Mezo.
/// priceX96 = (MUSD/USD) / (BTC/USD) * 2^96
/// BTC/USD: Mezo Skip oracle (Chainlink-compatible, 18 decimals)
/// MUSD/USD: Mezo Pyth oracle (8 decimals, expo = -8)
contract MezoMUSDOracle is ICustomPriceOracle {
    address private constant SKIP_BTC_USD = 0x7b7c000000000000000000000000000000000015;
    address private constant PYTH = 0x2880aB155794e7179c9eE2e38200202908C17B43;
    bytes32 private constant MUSD_USD_FEED_ID = 0x0617a9b725011a126a2b9fd53563f4236501f32cf76d877644b943394606c6de;

    function priceX96() external view returns (uint256) {
        (, int256 btcPrice,,,) = IAggregatorV3(SKIP_BTC_USD).latestRoundData(); // 18 decimals
        IPyth.PriceFeed memory feed = IPyth(PYTH).queryPriceFeed(MUSD_USD_FEED_ID);
        uint256 musdPrice = uint256(uint64(feed.price.price)); // 8 decimals
        return Math.mulDiv(2 ** 96, musdPrice * 1e10, uint256(btcPrice));
    }
}
