// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICustomPriceOracle {
    function priceX96() external view returns (uint256);
}
