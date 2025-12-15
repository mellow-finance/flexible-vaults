// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

import "scripts/common/interfaces/IDeployVaultFactoryRegistry.sol";
import "src/vaults/VaultConfigurator.sol";

interface IDeployVaultFactory {
    error ZeroAddress();
    error LengthMismatch();
    error SubvaultNotAllowed(address);
    error AlreadyInitialized();
    error NotYetDeployed();
    error Forbidden();

    struct QueueParams {
        uint256 version;
        uint256 isDeposit; // 1 = deposit, 0 = redeem
        address asset;
        bytes data;
    }

    struct SubvaultParams {
        uint256 version;
        uint256 verifierVersion;
        address[] assets;
        int256 limit;
    }

    struct FeeManagerParams {
        address owner;
        uint256 depositFeeD6;
        uint256 redeemFeeD6;
        uint256 performanceFeeD6;
        uint256 protocolFeeD6;
    }

    struct SubvaultRoot {
        address subvault;
        bytes32 merkleRoot;
    }

    struct DeployVaultConfig {
        string vaultName;
        string vaultSymbol;
        // Actors
        address proxyAdmin;
        address lazyVaultAdmin;
        address activeVaultAdmin;
        address oracleUpdater;
        address curator;
        address pauser;
        // Fee manager
        FeeManagerParams feeManagerParams;
        // Share manager
        bytes32 shareManagerWhitelistMerkleRoot;
        // Risk manager
        int256 riskManagerLimit;
        // Assets
        address[] allowedAssets;
        uint256[] allowedAssetsPrices;
        SubvaultParams[] subvaultParams;
        QueueParams[] queues;
        // oracle
        IOracle.SecurityParams securityParams;
        uint256 addOracleSubmitter; // 0 = no, 1 = yes
        address[] timelockProposers;
        address[] timelockExecutors;
        // other params can be added here as needed
        address defaultDepositHook;
        address defaultRedeemHook;
        uint256 queueLimit;
        // Versions
        uint256 vaultVersion;
        uint256 shareManagerVersion;
        uint256 feeManagerVersion;
        uint256 riskManagerVersion;
        uint256 oracleVersion;
        address timelockController;
        address oracleSubmitter;
        address deployer;
    }

    /**
     * @notice Deploys a new Vault with the given configuration.
     * @param $ The configuration parameters for the Vault deployment.
     * @return vault The address of the newly deployed Vault.
     */
    function deployVault(DeployVaultConfig calldata $) external returns (Vault vault);

    /**
     * @notice Finalizes the deployment of a Vault by setting up fee manager, queues, price reports, security params,
     * subvault roots, emergency pause, and role holders.
     * @param vault The Vault to finalize deployment for.
     * @param subvaultRoots The Merkle roots for the subvaults. Must be in the same order as subvaults in the Vault.
     * @param holders The role holders for the Vault.
     */
    function finalizeDeployment(Vault vault, SubvaultRoot[] memory subvaultRoots, Vault.RoleHolder[] memory holders)
        external;

    /**
     * @notice Returns the initialization parameters for a Vault based on the given deployment configuration.
     * @param $ The configuration parameters for the Vault deployment.
     * @return The initialization parameters for the Vault.
     */
    function getInitVaultParams(DeployVaultConfig memory $)
        external
        view
        returns (VaultConfigurator.InitParams memory);

    function getRegistry() external view returns (IDeployVaultFactoryRegistry);
}
