// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/external/chainlink/IAggregatorV3.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev price := aggregator1 * aggregator2 * multiplier / (aggregator3 * divisor)
contract OracleCombinator is IAggregatorV3 {
    error InvalidState();

    address public immutable aggregator1;
    address public immutable aggregator2;
    address public immutable aggregator3;
    uint256 public immutable multiplier;
    uint256 public immutable divisor;

    uint256 public immutable minPrice;
    uint256 public immutable maxPrice;

    string public description;

    constructor(
        address aggregator1_,
        address aggregator2_,
        address aggregator3_,
        uint256 multiplier_,
        uint256 divisor_,
        uint256 minPrice_,
        uint256 maxPrice_,
        string memory description_
    ) {
        aggregator1 = aggregator1_;
        aggregator2 = aggregator2_;
        aggregator3 = aggregator3_;

        if (
            multiplier_ == 0 || divisor_ == 0 || minPrice_ == 0 || minPrice_ > maxPrice_
                || maxPrice_ > uint256(type(int256).max)
        ) {
            revert InvalidState();
        }

        multiplier = multiplier_;
        divisor = divisor_;

        minPrice = minPrice_;
        maxPrice = maxPrice_;

        description = description_;
    }

    function get(address aggregator) public view returns (uint256) {
        if (aggregator == address(0)) {
            return 1;
        }
        int256 price = IAggregatorV3(aggregator).latestAnswer();
        if (price <= 0) {
            revert InvalidState();
        }
        return uint256(price);
    }

    function getRate() public view returns (uint256 price) {
        price = Math.mulDiv(get(aggregator1) * get(aggregator2), multiplier, get(aggregator3) * divisor);
        if (price > maxPrice) {
            price = maxPrice;
        } else if (price < minPrice) {
            price = minPrice;
        }
    }

    function latestAnswer() public view returns (int256) {
        return int256(getRate());
    }
}
