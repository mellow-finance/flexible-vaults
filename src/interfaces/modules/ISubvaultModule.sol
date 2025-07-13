// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";

/// @title ISubvaultModule
/// @notice Interface for a Subvault module used in modular vault architecture.
/// @dev A Subvault is a child vault that holds assets and can release them to its parent vault upon request.
/// Each Subvault is isolated and may integrate with external protocols through its own Verifier & CallModule, enabling
/// fine-grained delegation of liquidity while maintaining separation between subvaults.
interface ISubvaultModule {
    /// @notice Reverts when a caller is not the associated vault.
    error NotVault();

    /// @notice Storage laylout of ISubvaultModule.
    /// @dev Stores the address of the parent vault that has permission to pull assets.
    struct SubvaultModuleStorage {
        address vault;
    }

    /// @notice Returns the address of the parent vault contract.
    /// @return address The vault address allowed to interact with this subvault.
    function vault() external view returns (address);

    /// @notice Transfers a specified amount of an asset to the vault.
    /// @dev Can only be called by the parent vault.
    /// @param asset Address of the ERC20 token or native ETH.
    /// @param value Amount of the asset to transfer.
    function pullAssets(address asset, uint256 value) external;

    /// @notice Emitted when assets are pulled from the subvault to the vault.
    /// @param asset Address of the asset that was pulled.
    /// @param to Recipient address (must be the vault).
    /// @param value Amount of the asset that was pulled.
    event AssetsPulled(address indexed asset, address indexed to, uint256 value);
}
