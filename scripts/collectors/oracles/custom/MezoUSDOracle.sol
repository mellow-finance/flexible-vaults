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

contract MezoUSDOracle is ICustomPriceOracle {
    address private constant SKIP_BTC_USD = 0x7b7c000000000000000000000000000000000015;

    function priceX96() external view returns (uint256) {
        (, int256 btcPrice,,,) = IAggregatorV3(SKIP_BTC_USD).latestRoundData(); // 18 decimals
        return Math.mulDiv(2 ** 96, 1e18, uint256(btcPrice));
    }
}
