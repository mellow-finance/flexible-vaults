// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAngleDistributor {
    /// @notice Toggles whitelisting for a given user and a given operator
    function toggleOperator(address user, address operator) external;
}
