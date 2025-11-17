// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICustomOracle {
    struct Balance {
        address asset;
        int256 balance;
        int256 value;
        string metadata;
        address holder;
    }

    struct Data {
        address oracle;
        uint256 timestamp;
        address denominator;
        string metadata;
    }

    function tvl(address vault, Data calldata data) external view returns (uint256);

    function tvl(address vault, address denominator) external view returns (uint256);
}
