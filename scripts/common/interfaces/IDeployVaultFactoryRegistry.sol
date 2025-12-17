// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Factory} from "../../../src/factories/Factory.sol";
import {IFeeManager} from "../../../src/interfaces/managers/IFeeManager.sol";
import {IRiskManager} from "../../../src/interfaces/managers/IRiskManager.sol";
import {IShareManager} from "../../../src/interfaces/managers/IShareManager.sol";
import {IOracle} from "../../../src/interfaces/oracles/IOracle.sol";

import {OracleSubmitter} from "../../../src/oracles/OracleSubmitter.sol";
import {Subvault} from "../../../src/vaults/Subvault.sol";
import {Vault} from "../../../src/vaults/Vault.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "scripts/common/interfaces/IDeployVaultFactory.sol";

/// @title DeployVaultFactoryRegistry interface
/// @notice Interface for registry that stores configuration and metadata for vaults deployed via DeployVaultFactory.
interface IDeployVaultFactoryRegistry {
    struct VaultDeployment {
        Vault vault;
        TimelockController timelockController;
        IOracle oracle;
        OracleSubmitter oracleSubmitter;
        IShareManager shareManager;
        IFeeManager feeManager;
        IRiskManager riskManager;
        address[] subvaults;
        address[] verifiers;
        address[] depositQueues;
        address[] redeemQueues;
    }

    // ----------------------------------------------------------------------------------------------
    //                                          Errors
    // ----------------------------------------------------------------------------------------------

    /// @notice Thrown when a bytes/string argument has zero length.
    error ZeroLength();

    /// @notice Thrown when a zero address is provided where a non-zero address is required.
    error ZeroAddress();

    /// @notice Thrown when a zero value is provided where a non-zero value is required.
    error ZeroValue();

    /// @notice Thrown when array lengths do not match where they are expected to.
    error LengthMismatch();

    /// @notice Thrown when an asset is not present in the allowed assets list.
    /// @param asset The asset that is not allowed.
    error AssetNotAllowed(address asset);

    /// @notice Thrown when attempting to initialize an already initialized registry.
    error AlreadyInitialized();

    /// @notice Thrown when trying to add a vault that has not been fully deployed/configured.
    error NotYetDeployed();

    /// @notice Thrown when a caller is not authorized to perform an operation.
    error Forbidden();

    // ----------------------------------------------------------------------------------------------
    //                                          Views
    // ----------------------------------------------------------------------------------------------

    /// @notice Returns the address of the DeployVaultFactory contract that is allowed to mutate this registry.
    /// @return deployVaultFactory Address of the factory contract.
    function deployVaultFactory() external view returns (address deployVaultFactory);

    // ----------------------------------------------------------------------------------------------
    //                                  Permissioned functions
    // ----------------------------------------------------------------------------------------------

    /// @notice Initializes the registry with the given DeployVaultFactory address.
    /// @dev Can only be called once; subsequent calls revert with AlreadyInitialized.
    /// @param deployVaultFactory_ Address of the DeployVaultFactory contract.
    function initialize(address deployVaultFactory_) external;

    /// @notice Marks a vault as deployed and adds it to the registry set.
    /// @dev Can only be called by the DeployVaultFactory.
    /// @param vault Address of the vault contract.
    function addDeployedVault(address vault) external;

    /// @notice Saves configuration for a vault deployed via the factory.
    /// @dev Also records the deployer address in the stored config.
    /// @param vault Address of the vault.
    /// @param deployer Address that initiated the deployment.
    /// @param config Full deployment configuration for the vault.
    function saveVaultConfig(address vault, address deployer, IDeployVaultFactory.DeployVaultConfig calldata config)
        external;

    /// @notice Sets the timelock controller address for a given vault.
    /// @dev Can only be called by the DeployVaultFactory.
    /// @param vault Address of the vault.
    /// @param timelockController Address of the timelock controller contract.
    function setTimelockController(address vault, address timelockController) external;

    /// @notice Sets the oracle submitter address for a given vault.
    /// @dev Can only be called by the DeployVaultFactory.
    /// @param vault Address of the vault.
    /// @param oracleSubmitter Address of the oracle submitter contract.
    function setOracleSubmitter(address vault, address oracleSubmitter) external;

    // ----------------------------------------------------------------------------------------------
    //                                      View functions
    // ----------------------------------------------------------------------------------------------

    /// @notice Checks if a given address is a registered vault in the registry.
    /// @param vault Address to check.
    /// @return True if the address is a registered vault, false otherwise.
    function isEntity(address vault) external view returns (bool);

    /// @notice Returns vault address and its config at a given index.
    /// @dev Index is over the internal set of registered vaults.
    /// @param index Index in the vault set.
    /// @return vault Address of the vault at the given index.
    /// @return config Deployment configuration stored for this vault.
    function getDeployVaultConfigAt(uint256 index)
        external
        view
        returns (address vault, IDeployVaultFactory.DeployVaultConfig memory config);

    /// @notice Returns vault address at a given index.
    /// @param index Index in the vault set.
    /// @return vault Address of the vault.
    function getVaultAt(uint256 index) external view returns (address vault);

    /// @notice Returns the list of all registered vaults.
    /// @return vaults_ Array of vault addresses.
    function getVaults() external view returns (address[] memory vaults_);

    /// @notice Returns the number of registered vaults.
    /// @return count Number of vaults.
    function getVaultCount() external view returns (uint256 count);

    /// @notice Returns the stored deployment configuration for a specific vault.
    /// @param vault Address of the vault.
    /// @return config Deployment configuration for the vault.
    function getDeployVaultConfig(address vault)
        external
        view
        returns (IDeployVaultFactory.DeployVaultConfig memory config);

    /// @notice Returns the full deployment description for a vault by index.
    /// @dev Includes vault, timelock, oracle, managers, subvaults and queues.
    /// @param index Index in the vault set.
    /// @return deployment Full VaultDeployment struct for the vault at the given index.
    function getVaultDeploymentAt(uint256 index)
        external
        view
        returns (IDeployVaultFactoryRegistry.VaultDeployment memory deployment);

    /// @notice Returns the full deployment description for a specific vault.
    /// @param vaultAddress Address of the vault.
    /// @return deployment Full VaultDeployment struct for the specified vault.
    function getVaultDeployment(address vaultAddress)
        external
        view
        returns (IDeployVaultFactoryRegistry.VaultDeployment memory deployment);

    /// @notice Returns the deployer address for a given vault.
    /// @param vault Address of the vault.
    /// @return deployer Address that deployed the vault.
    function getVaultDeployer(address vault) external view returns (address deployer);

    /// @notice Returns the timelock controller for a given vault.
    /// @param vault Address of the vault.
    /// @return timelockController Address of the timelock controller.
    function getVaultTimelockController(address vault) external view returns (address timelockController);

    /// @notice Validates the given deployment configuration.
    /// @dev Reverts on invalid configuration (zero addresses, empty arrays, mismatched lengths, etc.).
    /// @param config Deployment configuration to validate.
    function validateDeployConfig(IDeployVaultFactory.DeployVaultConfig calldata config) external view;
}
