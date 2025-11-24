// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IUniswapV3Factory {
    function getPool(address token0, address token1, uint24 fee) external view returns (address);
}
