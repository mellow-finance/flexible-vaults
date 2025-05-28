// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}
