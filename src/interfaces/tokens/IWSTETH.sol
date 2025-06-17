// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWSTETH {
    function stETH() external view returns (address);

    function wrap(uint256 _stETHAmount) external returns (uint256);
}
