// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";

interface IPyth {
    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/documentation/pythnet-price-feeds/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint256 publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }

    function queryPriceFeed(bytes32 id) external view returns (PriceFeed memory priceFeed);
}

interface IAggregatorV3 {
    function latestAnswer() external view returns (int256);
}

contract MUSDOraclePyth {
    address private constant PYTH_ADDRESS = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
    bytes32 private constant MUSD_USD_PRICE_ID = 0x0617a9b725011a126a2b9fd53563f4236501f32cf76d877644b943394606c6de;

    function priceX96() external view returns (uint256) {
        IPyth.PriceFeed memory musdPriceFeed = IPyth(PYTH_ADDRESS).queryPriceFeed(MUSD_USD_PRICE_ID);
        uint256 musdPrice = uint256(uint64(musdPriceFeed.price.price)); // 8 decimals
        uint256 ethPrice = uint256(IAggregatorV3(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestAnswer());
        return Math.mulDiv(2 ** 96, musdPrice, ethPrice);
    }
}
