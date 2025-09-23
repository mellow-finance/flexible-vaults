// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAaveOracleV3 {
    function getAssetPrice(address) external view returns (uint256);
}
