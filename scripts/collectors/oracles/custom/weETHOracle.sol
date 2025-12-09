// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../IAggregatorV3.sol";
import "../ICustomPriceOracle.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

contract weETHOracle {
    function priceX96() external view returns (uint256) {
        int256 price = IAggregatorV3(0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22).latestAnswer();
        return Math.mulDiv(uint256(price), 2 ** 96, 1 ether);
    }
}
