// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IDistributionCollector {
    struct Balance {
        address asset;
        int256 balance;
        string metadata;
        address holder;
    }

    function getDistributions(address holder, bytes memory protocolDeployment, address[] calldata assets)
        external
        view
        returns (Balance[] memory balances);
}
