// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title IFactoryEntity
interface IFactoryEntity {
    /// @notice Initializes the factory-created entity with arbitrary initialization data.
    /// @param initParams The initialization parameters.
    function initialize(bytes calldata initParams) external;

    /// @notice Emitted once the entity has been initialized.
    /// @param initParams The initialization parameters.
    event Initialized(bytes initParams);
}
