// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";
import "../managers/IRiskManager.sol";
import "./IACLModule.sol";
import "./IShareModule.sol";
import "./ISubvaultModule.sol";
import "./IVerifierModule.sol";

/// @title IVaultModule
/// @notice Interface for a VaultModule that manages and coordinates asset flows
/// and sub-vault connections within a modular vault architecture.
interface IVaultModule is IACLModule {
    /// @dev Thrown when trying to reconnect a subvault that is already connected.
    error AlreadyConnected(address subvault);

    /// @dev Thrown when trying to disconnect a subvault that is not currently connected.
    error NotConnected(address subvault);

    /// @dev Thrown when the provided address is not a valid factory-deployed entity.
    error NotEntity(address subvault);

    /// @dev Thrown when a given subvault is not correctly configured.
    error InvalidSubvault(address subvault);

    /// @notice Storage structure used to track vault state and subvaults.
    struct VaultModuleStorage {
        address riskManager;
        EnumerableSet.AddressSet subvaults;
    }

    /// @notice Role that allows the creation of new subvaults.
    function CREATE_SUBVAULT_ROLE() external view returns (bytes32);

    /// @notice Role that allows disconnecting existing subvaults.
    function DISCONNECT_SUBVAULT_ROLE() external view returns (bytes32);

    /// @notice Role identifier for reconnecting subvaults.
    /// @dev Grants permission to reattach a subvault to the vault system.
    /// This includes both re-connecting a previously disconnected subvault
    /// and connecting a new, properly configured subvault for the first time.
    /// Used to maintain modularity and support hot-swapping of subvaults.
    function RECONNECT_SUBVAULT_ROLE() external view returns (bytes32);

    /// @notice Role that allows pulling assets from subvaults.
    function PULL_LIQUIDITY_ROLE() external view returns (bytes32);

    /// @notice Role that allows pushing assets into subvaults.
    function PUSH_LIQUIDITY_ROLE() external view returns (bytes32);

    /// @notice Returns the factory used to deploy new subvaults.
    function subvaultFactory() external view returns (IFactory);

    /// @notice Returns the factory used to deploy verifiers.
    function verifierFactory() external view returns (IFactory);

    /// @notice Returns the total number of connected subvaults.
    function subvaults() external view returns (uint256);

    /// @notice Returns the address of the subvault at a specific index.
    /// @param index Index in the set of subvaults.
    function subvaultAt(uint256 index) external view returns (address);

    /// @notice Checks whether a given address is currently an active subvault.
    /// @param subvault Address to check.
    function hasSubvault(address subvault) external view returns (bool);

    /// @notice Returns the address of the risk manager module.
    function riskManager() external view returns (IRiskManager);

    /// @notice Creates and connects a new subvault.
    /// @param version Version of the subvault contract to deploy.
    /// @param owner Owner of the newly created subvault.
    /// @param verifier Verifier contract used for permissions within the subvault.
    /// @return subvault Address of the newly created subvault.
    function createSubvault(uint256 version, address owner, address verifier) external returns (address subvault);

    /// @notice Disconnects a subvault from the vault.
    /// @param subvault Address of the subvault to disconnect.
    function disconnectSubvault(address subvault) external;

    /// @notice Reconnects a subvault to the main vault system.
    /// @dev Can be used to reattach either:
    /// - A previously disconnected subvault, or
    /// - A newly created and properly configured subvault.
    /// Requires the caller to have the `RECONNECT_SUBVAULT_ROLE`.
    /// @param subvault The address of the subvault to reconnect.
    function reconnectSubvault(address subvault) external;

    /// @notice Sends a specified amount of assets from the vault to a connected subvault.
    /// @param subvault Address of the destination subvault.
    /// @param asset Address of the asset to transfer.
    /// @param value Amount of the asset to send.
    function pushAssets(address subvault, address asset, uint256 value) external;

    /// @notice Pulls a specified amount of assets from a connected subvault into the vault.
    /// @param subvault Address of the source subvault.
    /// @param asset Address of the asset to transfer.
    /// @param value Amount of the asset to receive.
    function pullAssets(address subvault, address asset, uint256 value) external;

    /// @notice Internally used function that transfers assets from the vault to a connected subvault.
    /// @dev Must be invoked by the vault itself via hook execution logic.
    /// @param subvault Address of the destination subvault.
    /// @param asset Address of the asset being transferred.
    /// @param value Amount of the asset being transferred.
    function hookPushAssets(address subvault, address asset, uint256 value) external;

    /// @notice Internally used function that pulls assets from a connected subvault into the vault.
    /// @dev Must be invoked by the vault itself via hook execution logic.
    /// @param subvault Address of the source subvault.
    /// @param asset Address of the asset being pulled.
    /// @param value Amount of the asset being pulled.
    function hookPullAssets(address subvault, address asset, uint256 value) external;

    /// @notice Emitted when a new subvault is created.
    event SubvaultCreated(address indexed subvault, uint256 version, address indexed owner, address indexed verifier);

    /// @notice Emitted when a subvault is disconnected.
    event SubvaultDisconnected(address indexed subvault);

    /// @notice Emitted when a subvault is reconnected.
    event SubvaultReconnected(address indexed subvault, address indexed verifier);

    /// @notice Emitted when assets are pulled from a subvault into the vault.
    event AssetsPulled(address indexed asset, address indexed subvault, uint256 value);

    /// @notice Emitted when assets are pushed from the vault into a subvault.
    event AssetsPushed(address indexed asset, address indexed subvault, uint256 value);
}
