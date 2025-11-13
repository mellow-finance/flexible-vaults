// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}
