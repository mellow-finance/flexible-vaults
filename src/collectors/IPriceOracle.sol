// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IPriceOracle {
    function priceX96() external view returns (uint256);

    function priceX96(address token) external view returns (uint256);

    function getValue(address token, uint256 amount) external view returns (uint256);

    function getValue(address token, address priceToken, uint256 amount) external view returns (uint256);
}
