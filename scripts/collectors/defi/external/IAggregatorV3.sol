// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAggregatorV3 {
    function latestAnswer() external view returns (int256);
}
