// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";

interface IAggregatorV3 {
    function latestAnswer() external view returns (int256);
}

contract USDCOracle {
    function priceX96() external view returns (uint256) {
        uint256 usdcPrice = uint256(IAggregatorV3(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6).latestAnswer());
        uint256 ethPrice = uint256(IAggregatorV3(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestAnswer());
        return Math.mulDiv(2 ** 96, usdcPrice * 1e12, ethPrice);
    }
}
