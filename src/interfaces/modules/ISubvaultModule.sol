// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";

/// @title ISubvaultModule
/// @notice Interface for a Subvault Module within the modular vault architecture.
/// A subvault is a child vault that holds and releases assets at the direction of its parent vault.
interface ISubvaultModule {
    /// @notice Reverts when a caller is not the associated vault.
    error NotVault();

    /// @notice Storage structure used by the SubvaultModule implementation.
    /// @dev Stores the address of the parent vault that has permission to pull assets.
    struct SubvaultModuleStorage {
        address vault;
    }

    /// @notice Returns the address of the parent vault contract.
    /// @return The vault address allowed to interact with this subvault.
    function vault() external view returns (address);

    /// @notice Transfers a specified amount of an asset to the vault.
    /// @dev Can only be called by the parent vault.
    /// @param asset Address of the ERC20 token or native ETH (using TransferLibrary convention).
    /// @param value Amount of the asset to transfer.
    function pullAssets(address asset, uint256 value) external;

    /// @notice Emitted when assets are pulled from the subvault to the vault.
    /// @param asset Address of the asset that was pulled.
    /// @param to Recipient address (must be the vault).
    /// @param value Amount of the asset that was pulled.
    event AssetsPulled(address indexed asset, address indexed to, uint256 value);
}
