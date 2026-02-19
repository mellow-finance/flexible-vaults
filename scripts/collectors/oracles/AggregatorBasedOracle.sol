// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IAggregatorV3.sol";
import "./ICustomPriceOracle.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract AggregatorBasedOracle is ICustomPriceOracle {
    address public immutable aggregator0;
    address public immutable aggregator1;
    int8 public immutable decimalShift;

    constructor(address aggregator0_, address aggregator1_, int8 decimalShift_) {
        aggregator0 = aggregator0_;
        aggregator1 = aggregator1_;
        decimalShift = decimalShift_;
    }

    function priceX96() external view returns (uint256) {
        int256 price0 = aggregator0 == address(0) ? int256(1) : IAggregatorV3(aggregator0).latestAnswer();
        int256 price1 = aggregator1 == address(0) ? int256(1) : IAggregatorV3(aggregator1).latestAnswer();
        if (decimalShift >= 0) {
            return Math.mulDiv(2 ** 96 * 10 ** uint8(decimalShift), uint256(price0), uint256(price1));
        } else {
            return Math.mulDiv(2 ** 96, uint256(price0), uint256(price1) * 10 ** uint8(-decimalShift));
        }
    }
}
