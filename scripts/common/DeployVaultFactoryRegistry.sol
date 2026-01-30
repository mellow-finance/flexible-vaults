// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/IDeployVaultFactory.sol";
import "./interfaces/IDeployVaultFactoryRegistry.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract DeployVaultFactoryRegistry is IDeployVaultFactoryRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public deployVaultFactory;

    EnumerableSet.AddressSet internal vaults;

    mapping(address => IDeployVaultFactory.DeployVaultConfig) internal deployVaultConfig;

    modifier onlyDeployVaultFactory() {
        if (msg.sender != deployVaultFactory) {
            revert Forbidden();
        }
        _;
    }

    // -----------------------------------------------------------------------------------------------
    //                              Permissioned functions
    // -----------------------------------------------------------------------------------------------

    /// @inheritdoc IDeployVaultFactoryRegistry
    function initialize(address deployVaultFactory_) external {
        if (deployVaultFactory != address(0)) {
            revert AlreadyInitialized();
        }
        if (deployVaultFactory_ == address(0)) {
            revert ZeroAddress();
        }
        deployVaultFactory = deployVaultFactory_;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function addDeployedVault(address vault) external onlyDeployVaultFactory {
        if (vault == address(0)) {
            revert ZeroAddress();
        }

        if (deployVaultConfig[vault].deployer == address(0)) {
            revert NotYetDeployed();
        }

        vaults.add(vault);
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function saveVaultConfig(address vault, address deployer, IDeployVaultFactory.DeployVaultConfig calldata config)
        external
        onlyDeployVaultFactory
    {
        if (deployer == address(0)) {
            revert ZeroAddress();
        }
        if (deployVaultConfig[vault].deployer != address(0)) {
            revert AlreadyInitialized();
        }

        validateDeployConfig(config);

        deployVaultConfig[vault] = config;
        deployVaultConfig[vault].deployer = deployer;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function setTimelockController(address vault, address timelockController) external onlyDeployVaultFactory {
        if (timelockController == address(0)) {
            revert ZeroAddress();
        }
        if (deployVaultConfig[vault].timelockController != address(0)) {
            revert AlreadyInitialized();
        }
        deployVaultConfig[vault].timelockController = timelockController;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function setOracleSubmitter(address vault, address oracleSubmitter) external onlyDeployVaultFactory {
        if (oracleSubmitter == address(0)) {
            revert ZeroAddress();
        }
        if (deployVaultConfig[vault].oracleSubmitter != address(0)) {
            revert AlreadyInitialized();
        }
        deployVaultConfig[vault].oracleSubmitter = oracleSubmitter;
    }

    // -----------------------------------------------------------------------------------------------
    //                              View functions
    // -----------------------------------------------------------------------------------------------

    /// @inheritdoc IDeployVaultFactoryRegistry
    function isEntity(address vault) external view returns (bool) {
        return vaults.contains(vault);
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultCount() external view returns (uint256) {
        return vaults.length();
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultAt(uint256 index) external view returns (address) {
        return vaults.at(index);
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getDeployVaultConfigAt(uint256 index)
        external
        view
        returns (address vault, IDeployVaultFactory.DeployVaultConfig memory config)
    {
        vault = vaults.at(index);
        config = deployVaultConfig[vault];
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getDeployVaultConfig(address vault) external view returns (IDeployVaultFactory.DeployVaultConfig memory) {
        return deployVaultConfig[vault];
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultDeploymentAt(uint256 index) external view returns (VaultDeployment memory deployment) {
        address vaultAddress = vaults.at(index);
        deployment = getVaultDeployment(vaultAddress);
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultDeployer(address vault) external view returns (address) {
        return deployVaultConfig[vault].deployer;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultTimelockController(address vault) external view returns (address) {
        return deployVaultConfig[vault].timelockController;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function getVaultDeployment(address vaultAddress) public view returns (VaultDeployment memory deployment) {
        Vault vault = Vault(payable(vaultAddress));
        deployment.vault = vault;
        deployment.timelockController =
            TimelockController(payable(deployVaultConfig[address(vault)].timelockController));
        deployment.oracleSubmitter = OracleSubmitter(payable(deployVaultConfig[address(vault)].oracleSubmitter));
        deployment.oracle = vault.oracle();
        deployment.shareManager = vault.shareManager();
        deployment.feeManager = vault.feeManager();
        deployment.riskManager = vault.riskManager();

        uint256 subvaultsCount = vault.subvaults();
        deployment.subvaults = new address[](subvaultsCount);
        deployment.verifiers = new address[](subvaultsCount);
        for (uint256 i = 0; i < subvaultsCount; i++) {
            deployment.subvaults[i] = vault.subvaultAt(i);
            deployment.verifiers[i] = address(Subvault(payable(deployment.subvaults[i])).verifier());
        }

        uint256 totalQueues;
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            totalQueues += vault.getQueueCount(vault.assetAt(i));
        }

        address[] memory depositQueues = new address[](totalQueues);
        address[] memory redeemQueues = new address[](totalQueues);

        uint256 depositIndex;
        uint256 redeemIndex;
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(asset);
            for (uint256 j = 0; j < queueCount; j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    depositQueues[depositIndex++] = queue;
                } else {
                    redeemQueues[redeemIndex++] = queue;
                }
            }
        }
        assembly {
            mstore(depositQueues, depositIndex)
            mstore(redeemQueues, redeemIndex)
        }
        deployment.depositQueues = depositQueues;
        deployment.redeemQueues = redeemQueues;
    }

    /// @inheritdoc IDeployVaultFactoryRegistry
    function validateDeployConfig(IDeployVaultFactory.DeployVaultConfig calldata $) public pure {
        if (bytes($.vaultName).length == 0) {
            revert ZeroLength();
        }
        if (bytes($.vaultSymbol).length == 0) {
            revert ZeroLength();
        }
        _checkAddressRoles($);
        _checkAssets($);
    }

    // -----------------------------------------------------------------------------------------------
    //                              Internal view functions
    // -----------------------------------------------------------------------------------------------

    function _checkAddressRoles(IDeployVaultFactory.DeployVaultConfig calldata $) internal pure {
        if ($.proxyAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.lazyVaultAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.activeVaultAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ($.oracleUpdater == address(0)) {
            revert ZeroAddress();
        }
        if ($.curator == address(0)) {
            revert ZeroAddress();
        }
        if ($.pauser == address(0)) {
            revert ZeroAddress();
        }
        if ($.feeManagerParams.owner == address(0)) {
            revert ZeroAddress();
        }
    }

    function _checkAssets(IDeployVaultFactory.DeployVaultConfig calldata $) internal pure {
        if ($.allowedAssets.length == 0) {
            revert ZeroLength();
        }
        for (uint256 i = 0; i < $.allowedAssets.length; i++) {
            if ($.allowedAssets[i] == address(0)) {
                revert ZeroAddress();
            }
        }
        if ($.queues.length == 0) {
            revert ZeroLength();
        }
        if ($.queueLimit < $.queues.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < $.queues.length; i++) {
            bool found;
            for (uint256 j = 0; j < $.allowedAssets.length; j++) {
                if ($.queues[i].asset == $.allowedAssets[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert AssetNotAllowed($.queues[i].asset);
            }
        }

        if ($.subvaultParams.length == 0) {
            revert ZeroLength();
        }

        for (uint256 i = 0; i < $.subvaultParams.length; i++) {
            if ($.subvaultParams[i].assets.length == 0) {
                revert ZeroLength();
            }
        }
        for (uint256 i = 0; i < $.subvaultParams.length; i++) {
            for (uint256 j = 0; j < $.subvaultParams[i].assets.length; j++) {
                bool found;
                for (uint256 k = 0; k < $.allowedAssets.length; k++) {
                    if ($.subvaultParams[i].assets[j] == $.allowedAssets[k]) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    revert AssetNotAllowed($.subvaultParams[i].assets[j]);
                }
            }
        }
        if ($.allowedAssetsPrices.length != $.allowedAssets.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < $.allowedAssetsPrices.length; i++) {
            if ($.allowedAssetsPrices[i] == 0) {
                revert ZeroValue();
            }
        }
    }
}
