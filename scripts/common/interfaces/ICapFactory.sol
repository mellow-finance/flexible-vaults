// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICapFactory {
    function createVault(address _owner, address _asset, address _agent, address _network)
        external
        returns (address vault, address delegator, address burner, address slasher, address stakerRewards);
}
