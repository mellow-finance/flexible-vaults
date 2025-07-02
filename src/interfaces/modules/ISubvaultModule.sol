// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";

interface ISubvaultModule {
    error NotVault();

    struct SubvaultModuleStorage {
        address vault;
    }

    // View functions

    function vault() external view returns (address);

    // Mutable functions

    function pullAssets(address asset, uint256 value) external;

    // Events

    event AssetsPulled(address indexed asset, address indexed to, uint256 value);
}
