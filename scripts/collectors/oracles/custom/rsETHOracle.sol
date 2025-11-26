// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../IAggregatorV3.sol";
import "../ICustomPriceOracle.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

contract rsETHOracle {
    function priceX96() external view returns (uint256) {
        int256 price = IAggregatorV3(0x9d2F2f96B24C444ee32E57c04F7d944bcb8c8549).latestAnswer();
        return Math.mulDiv(uint256(price), 2 ** 96, 1 ether);
    }
}
