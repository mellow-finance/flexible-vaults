// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IFactoryEntity {
    function initialize(bytes calldata initParams) external;

    event Initialized(bytes initParams);
}
