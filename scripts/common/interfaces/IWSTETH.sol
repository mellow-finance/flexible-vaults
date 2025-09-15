// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWSTETH {
    function getStETHByWstETH(uint256) external view returns (uint256);
    function getWstETHByStETH(uint256) external view returns (uint256);
}
