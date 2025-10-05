// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICustomOracle {
    function tvl(address vault, address denominator) external view returns (uint256);
}
