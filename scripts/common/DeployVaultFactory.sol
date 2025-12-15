// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Permissions.sol";

import "./interfaces/IDeployVaultFactory.sol";
import "./interfaces/IDeployVaultFactoryRegistry.sol";
import "./interfaces/Imports.sol";

import "scripts/common/interfaces/IOracleSubmitterFactory.sol";
import {OracleSubmitter} from "src/oracles/OracleSubmitter.sol";
import "src/vaults/Subvault.sol";

contract DeployVaultFactory is IDeployVaultFactory {
    event VaultDeployed(address indexed vault, address indexed deployer);

    VaultConfigurator internal vaultConfigurator_;
    Factory internal verifierFactory_;
    IDeployVaultFactoryRegistry internal registry_;
    IOracleSubmitterFactory internal oracleSubmitterFactory_;

    constructor(address vaultConfigurator, address verifierFactory, address oracleSubmitterFactory, address registry) {
        if (
            vaultConfigurator == address(0) || verifierFactory == address(0) || oracleSubmitterFactory == address(0)
                || registry == address(0)
        ) {
            revert ZeroAddress();
        }

        vaultConfigurator_ = VaultConfigurator(vaultConfigurator);
        verifierFactory_ = Factory(verifierFactory);
        oracleSubmitterFactory_ = IOracleSubmitterFactory(oracleSubmitterFactory);
        registry_ = IDeployVaultFactoryRegistry(registry_);
        registry_.initialize(address(this));
    }

    /// @inheritdoc IDeployVaultFactory
    function deployVault(DeployVaultConfig calldata $) external returns (Vault vault) {
        if ($.queueLimit < $.queues.length) {
            revert LengthMismatch();
        }
        VaultConfigurator.InitParams memory initParams = _getInitVaultParams(
            $,
            IOracle.SecurityParams({
                maxAbsoluteDeviation: 1 wei,
                suspiciousAbsoluteDeviation: 1 wei,
                maxRelativeDeviationD18: 1 wei,
                suspiciousRelativeDeviationD18: 1 wei,
                /// @dev set very low timeouts for now
                timeout: 1 seconds,
                depositInterval: 1 seconds,
                redeemInterval: 1 seconds
            })
        );

        // create vault
        vault = _createVault(initParams);

        // create subvaults
        _createSubvaults(vault, $);

        // initial price reports
        _pushReports(vault.oracle(), $.allowedAssets, $.allowedAssetsPrices);

        // save config and allowed deployer for finalizeDeployment
        registry_.saveVaultConfig(address(vault), msg.sender, $);
    }

    /// @inheritdoc IDeployVaultFactory
    function finalizeDeployment(Vault vault, SubvaultRoot[] memory subvaultRoots, Vault.RoleHolder[] memory holders)
        external
    {
        address deployer = msg.sender;

        if (registry_.isEntity(address(vault))) {
            revert AlreadyInitialized();
        }

        DeployVaultConfig memory $ = registry_.getDeployVaultConfig(address(vault));
        address baseAsset = $.allowedAssets[0];

        if (baseAsset == address(0)) {
            revert NotYetDeployed();
        }

        if (deployer != registry_.getVaultDeployer(address(vault))) {
            revert Forbidden();
        }

        IFeeManager feeManager = vault.feeManager();
        IOracle oracle = vault.oracle();

        // fee manager setup
        feeManager.setBaseAsset(address(vault), baseAsset);
        Ownable(address(feeManager)).transferOwnership($.feeManagerParams.owner);

        // create all queues
        _createQueues(vault, $.proxyAdmin, $.queues);

        // initial price reports
        _pushReports(oracle, $.allowedAssets, $.allowedAssetsPrices);

        // set actual security params
        oracle.setSecurityParams($.securityParams);

        // set subvault merkle roots
        _setSubvaultRoots(vault, subvaultRoots);

        // emergency pause setup
        TimelockController timelockController = _scheduleEmergencyPauses(vault, $);
        registry_.setTimelockController(address(vault), address(timelockController));

        address oracleSubmitter;
        if ($.addOracleSubmitter == 1) {
            // deploy oracle submitter
            oracleSubmitter = oracleSubmitterFactory_.deployOracleSubmitter(
                $.proxyAdmin, $.oracleUpdater, $.activeVaultAdmin, address(oracle)
            );
            registry_.setOracleSubmitter(address(vault), oracleSubmitter);
        }

        // give roles to actual vault role holders
        _transferRoleHolders(vault, oracleSubmitter, holders);

        registry_.addDeployedVault(address(vault));

        emit VaultDeployed(address(vault), deployer);
    }

    /// @inheritdoc IDeployVaultFactory
    function getInitVaultParams(DeployVaultConfig memory $) public view returns (VaultConfigurator.InitParams memory) {
        return _getInitVaultParams($, $.securityParams);
    }

    /// @inheritdoc IDeployVaultFactory
    function registry() external view returns (IDeployVaultFactoryRegistry) {
        return registry_;
    }

    /// @inheritdoc IDeployVaultFactory
    function vaultConfigurator() external view returns (VaultConfigurator) {
        return vaultConfigurator_;
    }

    /// @inheritdoc IDeployVaultFactory
    function verifierFactory() external view returns (Factory) {
        return verifierFactory_;
    }

    /// @inheritdoc IDeployVaultFactory
    function oracleSubmitterFactory() external view returns (IOracleSubmitterFactory) {
        return oracleSubmitterFactory_;
    }

    function _getInitVaultParams(DeployVaultConfig memory $, IOracle.SecurityParams memory securityParams)
        internal
        view
        returns (VaultConfigurator.InitParams memory)
    {
        return VaultConfigurator.InitParams({
            version: $.vaultVersion,
            proxyAdmin: $.proxyAdmin,
            vaultAdmin: $.lazyVaultAdmin,
            shareManagerVersion: $.shareManagerVersion,
            shareManagerParams: abi.encode($.shareManagerWhitelistMerkleRoot, $.vaultName, $.vaultSymbol),
            feeManagerVersion: $.feeManagerVersion,
            feeManagerParams: abi.encode(
                address(this),
                $.feeManagerParams.owner,
                $.feeManagerParams.depositFeeD6,
                $.feeManagerParams.redeemFeeD6,
                $.feeManagerParams.performanceFeeD6,
                $.feeManagerParams.protocolFeeD6
            ),
            riskManagerVersion: $.riskManagerVersion,
            riskManagerParams: abi.encode($.riskManagerLimit),
            oracleVersion: $.oracleVersion,
            oracleParams: abi.encode(securityParams, $.allowedAssets),
            defaultDepositHook: $.defaultDepositHook,
            defaultRedeemHook: $.defaultRedeemHook,
            queueLimit: $.queueLimit,
            /// @dev give full control to this for now
            roleHolders: _getTemporaryRoleHolders()
        });
    }

    function _createVault(VaultConfigurator.InitParams memory initParams) internal returns (Vault vault) {
        (,,,, address vault_) = vaultConfigurator_.create(initParams);
        vault = Vault(payable(vault_));
    }

    function _createQueues(Vault vault, address proxyAdmin, QueueParams[] memory queues) internal {
        for (uint256 i = 0; i < queues.length; i++) {
            QueueParams memory params = queues[i];
            vault.createQueue(params.version, params.isDeposit == 1, proxyAdmin, params.asset, params.data);
        }
    }

    function _createSubvaults(Vault vault, DeployVaultConfig memory $) internal {
        IRiskManager riskManager = vault.riskManager();

        for (uint256 i = 0; i < $.subvaultParams.length; i++) {
            address verifier = verifierFactory_.create(
                $.subvaultParams[i].verifierVersion, $.proxyAdmin, abi.encode(vault, bytes32(0))
            );
            address subvault = vault.createSubvault($.subvaultParams[i].version, $.proxyAdmin, verifier);

            riskManager.allowSubvaultAssets(subvault, $.subvaultParams[i].assets);
            riskManager.setSubvaultLimit(subvault, $.subvaultParams[i].limit);
        }
    }

    function _setSubvaultRoots(Vault vault, SubvaultRoot[] memory subvaultRoots) internal {
        for (uint256 i = 0; i < subvaultRoots.length; i++) {
            if (vault.subvaultAt(i) != subvaultRoots[i].subvault) {
                revert SubvaultNotAllowed(subvaultRoots[i].subvault);
            }
            Subvault(payable(subvaultRoots[i].subvault)).verifier().setMerkleRoot(subvaultRoots[i].merkleRoot);
        }
    }

    function _scheduleEmergencyPauses(Vault vault, DeployVaultConfig memory $)
        internal
        returns (TimelockController timelockController)
    {
        address[] memory proposers = new address[]($.timelockProposers.length + 1);

        proposers[0] = address(this);
        for (uint256 i = 0; i < $.timelockProposers.length; i++) {
            proposers[i + 1] = $.timelockProposers[i];
        }

        timelockController = new TimelockController(0, proposers, $.timelockExecutors, $.lazyVaultAdmin);

        timelockController.schedule(
            address(vault.shareManager()),
            0,
            abi.encodeCall(
                IShareManager.setFlags,
                (
                    IShareManager.Flags({
                        hasMintPause: true,
                        hasBurnPause: true,
                        hasTransferPause: true,
                        hasWhitelist: true,
                        hasTransferWhitelist: true,
                        globalLockup: type(uint32).max
                    })
                )
            ),
            bytes32(0),
            bytes32(0),
            0
        );

        for (uint256 i = 0; i < $.allowedAssets.length; i++) {
            if (vault.getQueueCount($.allowedAssets[i]) > 0) {
                address queue = vault.queueAt($.allowedAssets[i], 0);
                timelockController.schedule(
                    address(vault),
                    0,
                    abi.encodeCall(IShareModule.setQueueStatus, (queue, true)),
                    bytes32(0),
                    bytes32(0),
                    0
                );
            }
        }
        for (uint256 i = 0; i < vault.subvaults(); i++) {
            timelockController.schedule(
                address(Subvault(payable(vault.subvaultAt(i))).verifier()),
                0,
                abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))),
                bytes32(0),
                bytes32(0),
                0
            );
        }
    }

    function _pushReports(IOracle oracle, address[] memory allowedAssets, uint256[] memory allowedAssetsPrices)
        internal
    {
        IOracle.Report[] memory reports = new IOracle.Report[](allowedAssets.length);
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            reports[i].asset = allowedAssets[i];
            reports[i].priceD18 = uint224(allowedAssetsPrices[i]);
        }

        oracle.submitReports(reports);
        for (uint256 i = 0; i < reports.length; i++) {
            IOracle.DetailedReport memory report = oracle.getReport(reports[i].asset);
            if (report.isSuspicious) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(report.timestamp));
            }
        }
    }

    function _getTemporaryRoleHolders() public view returns (Vault.RoleHolder[] memory holders) {
        uint256 index;
        address this_ = address(this);
        holders = new Vault.RoleHolder[](9);
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, this_);
    }

    function _transferRoleHolders(Vault vault, address oracleSubmitter, Vault.RoleHolder[] memory holders) internal {
        address timelockController = registry_.getVaultTimelockController(address(vault));

        /// @dev cache role constants for size contract reduction
        bytes32 ACCEPT_REPORT_ROLE = Permissions.ACCEPT_REPORT_ROLE;
        bytes32 SUBMIT_REPORTS_ROLE = Permissions.SUBMIT_REPORTS_ROLE;

        // give roles to actual vault role holders
        for (uint256 i = 0; i < holders.length; i++) {
            if (oracleSubmitter != address(0)) {
                if (holders[i].role == SUBMIT_REPORTS_ROLE || holders[i].role == ACCEPT_REPORT_ROLE) {
                    continue;
                }
            }
            vault.grantRole(holders[i].role, holders[i].holder);
        }

        // oracle submitter roles:
        if (oracleSubmitter != address(0)) {
            vault.grantRole(SUBMIT_REPORTS_ROLE, oracleSubmitter);
            vault.grantRole(ACCEPT_REPORT_ROLE, oracleSubmitter);
        }

        // emergency pauser roles:
        vault.grantRole(Permissions.SET_FLAGS_ROLE, timelockController);
        vault.grantRole(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
        vault.grantRole(Permissions.SET_QUEUE_STATUS_ROLE, timelockController);

        // renounce roles from this contract
        Vault.RoleHolder[] memory temporaryHolders = _getTemporaryRoleHolders();
        for (uint256 i = 0; i < temporaryHolders.length; i++) {
            vault.renounceRole(temporaryHolders[i].role, address(this));
        }

        TimelockController(payable(timelockController)).renounceRole(
            Permissions.TIMELOCK_CONTROLLER_PROPOSER_ROLE, address(this)
        );
        TimelockController(payable(timelockController)).renounceRole(
            Permissions.TIMELOCK_CONTROLLER_CANCELLER_ROLE, address(this)
        );
    }
}
