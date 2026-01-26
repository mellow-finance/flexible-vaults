// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAngleDistributor {
    function toggleOperator(address user, address operator) external;
}
