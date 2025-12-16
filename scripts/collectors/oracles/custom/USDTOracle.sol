// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";

interface IAggregatorV3 {
    function latestAnswer() external view returns (int256);
}

contract USDTOracle {
    function priceX96() external view returns (uint256) {
        uint256 usdtPrice = uint256(IAggregatorV3(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D).latestAnswer());
        uint256 ethPrice = uint256(IAggregatorV3(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestAnswer());
        return Math.mulDiv(2 ** 96, usdtPrice * 1e12, ethPrice);
    }
}
