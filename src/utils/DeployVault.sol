// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "src/vaults/Subvault.sol";
import "src/vaults/VaultConfigurator.sol";

import "scripts/common/interfaces/Imports.sol";
import "scripts/common/Permissions.sol";

contract DeployVault {
    error ZeroLength();
    error ZeroAddress();
    error ZeroValue();
    error LengthMismatch();
    error BaseAssetError();
    error AssetNotAllowed(address asset);

    struct SubvaultConfig {
        bytes32 merkleRoot;
        address[] allowedSubvaultAssets;
    }

    struct DeployVaultConfig {
        string vaultName;
        string vaultSymbol;
        // subvaults
        SubvaultConfig[] subvaultConfigs;
        // Actors
        address proxyAdmin;
        address lazyVaultAdmin;
        address activeVaultAdmin;
        address oracleUpdater;
        address curator;
        address pauser;
        address feeManagerOwner;
        // Assets
        address baseAsset;
        address[] allowedAssets;
        uint224[] allowedAssetsPrices;
        address[] depositAssets;
        address[] withdrawAssets;
        // security
        IOracle.SecurityParams securityParams;
    }

    struct SubvaultDeployment {
        address subvault;
        address verifier;
        bytes32 merkleRoot;
    }

    struct VaultDeployment {
        Vault vault;
        TimelockController timelockController;
        IOracle oracle;
        IShareManager shareManager;
        IFeeManager feeManager;
        IRiskManager riskManager;
        SubvaultDeployment[] subvaults;
        address[] depositQueues;
        address[] redeemQueues;
    }

    address public immutable ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    VaultConfigurator public immutable vaultConfigurator;
    Factory public immutable verifierFactory;
    address public immutable defaultDepositHook;
    address public immutable defaultRedeemHook;

    constructor(address vaultConfigurator_, address verifierFactory_, address defaultDepositHook_, address defaultRedeemHook_) {
        vaultConfigurator = VaultConfigurator(vaultConfigurator_);
        verifierFactory = Factory(verifierFactory_);
        defaultDepositHook = defaultDepositHook_;
        defaultRedeemHook = defaultRedeemHook_;
    }

    function deploy(DeployVaultConfig calldata $) external returns (VaultDeployment memory deployment) {
        TimelockController timelockController = _createTimelockController(
            $.lazyVaultAdmin
        );

        Vault.RoleHolder[] memory holders = _setVaultRoleHolders($, address(timelockController), true);

        VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: $.proxyAdmin,
            vaultAdmin: $.lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), $.vaultName, $.vaultSymbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(address(this), $.feeManagerOwner, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode($.securityParams, $.allowedAssets),
            defaultDepositHook: defaultDepositHook,
            defaultRedeemHook: defaultRedeemHook,
            queueLimit: $.depositAssets.length + $.withdrawAssets.length,
            roleHolders: holders
        });

        Vault vault = _createVault(initParams);

        deployment.vault = vault;
        deployment.timelockController = timelockController;
        deployment.feeManager = vault.feeManager();
        deployment.riskManager = vault.riskManager();
        deployment.shareManager = vault.shareManager();
        deployment.oracle = vault.oracle();

        (deployment.depositQueues, deployment.redeemQueues) = _createQueues(vault, $.proxyAdmin, $.depositAssets, $.withdrawAssets);

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), $.baseAsset);
        Ownable(address(vault.feeManager())).transferOwnership($.feeManagerOwner);

        // subvault setup
        deployment.subvaults = _createSubvaults(vault, $.proxyAdmin, $.subvaultConfigs);

        // emergency pause setup
        _scheduleEmergencyPauses(vault, $.allowedAssets, timelockController);

        // initial price reports
        _pushInitialReports(vault, $.allowedAssets, $.allowedAssetsPrices);

        // initial deposit
        _makeInitialDeposit(vault, $.baseAsset);

        // finalize deployment
        _renounceTemporaryRoles(vault, timelockController, holders);
    }
    
    function validateDeployConfig(DeployVaultConfig memory $) public view {
        if (bytes($.vaultName).length == 0) {
            revert ZeroLength();
        }
        if (bytes($.vaultSymbol).length == 0) {
            revert ZeroLength();
        }
        _checkAddressRoles($);
        _checkAssets($);
    }

    function _checkAddressRoles(DeployVaultConfig memory $) internal view {
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
        if ($.feeManagerOwner == address(0)) {
            revert ZeroAddress();
        }
    }

    function _checkAssets(DeployVaultConfig memory $) internal view {
        if ($.baseAsset == address(0)) {
            revert ZeroAddress();
        }
        if ($.allowedAssets.length == 0) {
            revert ZeroLength();
        }
        for (uint256 i = 0; i < $.allowedAssets.length; i++) {
            if ($.allowedAssets[i] == address(0)) {
                revert ZeroAddress();
            }
        }
        if ($.depositAssets.length == 0) {
            revert ZeroLength();
        }
        if ($.withdrawAssets.length == 0) {
            revert ZeroLength();
        }
        bool baseAssetFound;
        for (uint256 i = 0; i < $.allowedAssets.length; i++) {
            if ($.baseAsset == $.allowedAssets[i]) {
                baseAssetFound = true;
                break;
            }
        }
        if (!baseAssetFound) {
            revert BaseAssetError();
        }
        for (uint256 i = 0; i < $.depositAssets.length; i++) {
            bool found;
            for (uint256 j = 0; j < $.allowedAssets.length; j++) {
                if ($.depositAssets[i] == $.allowedAssets[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert AssetNotAllowed($.depositAssets[i]);
            }
        }
        for (uint256 i = 0; i < $.withdrawAssets.length; i++) {
            bool found;
            for (uint256 j = 0; j < $.allowedAssets.length; j++) {
                if ($.withdrawAssets[i] == $.allowedAssets[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert AssetNotAllowed($.withdrawAssets[i]);
            }
        }

        if ($.subvaultConfigs.length == 0) {
            revert ZeroLength();
        }

        for (uint256 i = 0; i < $.subvaultConfigs.length; i++) {
            if ($.subvaultConfigs[i].allowedSubvaultAssets.length == 0) {
                revert ZeroLength();
            }
        }
        for (uint256 i = 0; i < $.subvaultConfigs.length; i++) {
            for (uint256 j = 0; j < $.subvaultConfigs[i].allowedSubvaultAssets.length; j++) {
                bool found;
                for (uint256 k = 0; k < $.allowedAssets.length; k++) {
                    if ($.subvaultConfigs[i].allowedSubvaultAssets[j] == $.allowedAssets[k]) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    revert AssetNotAllowed($.subvaultConfigs[i].allowedSubvaultAssets[j]);
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

    function _createVault(VaultConfigurator.InitParams memory initParams)
        internal
        returns (Vault vault)
    {
        (,,,, address vault_) = vaultConfigurator.create(initParams);
        vault = Vault(payable(vault_));
    }

    function _createTimelockController(address lazyVaultAdmin)
        internal
        returns (TimelockController timelockController)
    {
        address[] memory proposers = new address[](2);
        address[] memory executors = new address[](1);

        proposers[0] = lazyVaultAdmin;
        proposers[1] = address(this);
        executors[0] = lazyVaultAdmin;

        timelockController = new TimelockController(0, proposers, executors, lazyVaultAdmin);
    }

    function _createQueues(Vault vault, address proxyAdmin, address[] memory depositAssets, address[] memory withdrawAssets)
        internal
        returns (address[] memory depositQueues, address[] memory redeemQueues)
    {
        depositQueues = new address[](depositAssets.length);
        redeemQueues = new address[](withdrawAssets.length);
        // deposit queues setup
        for (uint256 i = 0; i < depositAssets.length; i++) {
            vault.createQueue(0, true, proxyAdmin, depositAssets[i], new bytes(0));
            depositQueues[i] = address(vault.queueAt(depositAssets[i], 0));
        }
        // redeem queues setup
        for (uint256 i = 0; i < withdrawAssets.length; i++) {
            vault.createQueue(0, false, proxyAdmin, withdrawAssets[i], new bytes(0));
            redeemQueues[i] = address(vault.queueAt(withdrawAssets[i], 1));
        }
    }

    function _createSubvaults(Vault vault, address proxyAdmin, SubvaultConfig[] memory subvaultConfigs)
        internal
        returns (SubvaultDeployment[] memory subvaultDeployments)
    {
        IRiskManager riskManager = vault.riskManager();

        subvaultDeployments = new SubvaultDeployment[](subvaultConfigs.length);
        for (uint256 i = 0; i < subvaultConfigs.length; i++) {
            subvaultDeployments[i].verifier =
                verifierFactory.create(0, proxyAdmin, abi.encode(vault, subvaultConfigs[i].merkleRoot));
            address subvault = vault.createSubvault(0, proxyAdmin, subvaultDeployments[i].verifier);
            subvaultDeployments[i].merkleRoot = subvaultConfigs[i].merkleRoot;

            riskManager.allowSubvaultAssets(subvault, subvaultConfigs[i].allowedSubvaultAssets);
            riskManager.setSubvaultLimit(subvault, type(int256).max / 2);

            subvaultDeployments[i].subvault = subvault;
        }
    }

    function _scheduleEmergencyPauses(Vault vault, address[] memory allowedAssets, TimelockController timelockController) internal {
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

        for (uint256 i = 0; i < allowedAssets.length; i++) {
            if (vault.getQueueCount(allowedAssets[i]) > 0) {
                address queue = vault.queueAt(allowedAssets[i], 0);
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

    function _pushInitialReports(Vault vault, address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
        internal
    {
        IOracle.Report[] memory reports = new IOracle.Report[](allowedAssets.length);
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            reports[i].asset = allowedAssets[i];
            reports[i].priceD18 = allowedAssetsPrices[i];
        }

        IOracle oracle = vault.oracle();
        oracle.submitReports(reports);
        uint256 timestamp = oracle.getReport(reports[0].asset).timestamp;
        for (uint256 i = 0; i < reports.length; i++) {
            oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(timestamp));
        }
    }

    function _makeInitialDeposit(Vault vault, address asset) internal {
        address depositQueue = address(vault.queueAt(asset, 0));
        if (depositQueue == address(0)) {
            revert ZeroAddress();
        }
        uint256 assetAmount;
        uint256 nativeAmount;
        if (asset != ETH) {
            assetAmount = IERC20(asset).balanceOf(address(this));
            IERC20(asset).approve(depositQueue, assetAmount);
        } else {
            nativeAmount = address(this).balance;
            assetAmount = nativeAmount;
        }
        if (assetAmount == 0) {
            revert ZeroValue();
        }
        IDepositQueue(depositQueue).deposit{value: nativeAmount}(uint224(assetAmount), address(0), new bytes32[](0));
    }

    function _setVaultRoleHolders(DeployVaultConfig memory $, address timelockController, bool withTemporaryRoles) public view returns (Vault.RoleHolder[] memory holders) {
        uint256 index;
        holders = new Vault.RoleHolder[](18 + (withTemporaryRoles ? 7 : 0));

        // lazyVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, $.lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, $.lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, $.lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, $.lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, $.lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, $.lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, $.activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, $.activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, $.activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, $.activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, $.activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, $.activeVaultAdmin);

        // emergency pauser roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        // oracle updater roles:
        holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, $.oracleUpdater);

        // curator roles:
        holders[index++] = Vault.RoleHolder(Permissions.CALLER_ROLE, $.curator);
        holders[index++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, $.curator);
        holders[index++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, $.curator);

        // temporary deployer roles
        if (withTemporaryRoles) {
            holders[index++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, address(this));
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, address(this));
        }
    }

    function _renounceTemporaryRoles(Vault vault, TimelockController timelockController, Vault.RoleHolder[] memory holders) internal {
        for (uint256 i = 0; i < holders.length; i++) {
            vault.renounceRole(holders[i].role, address(this));
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), address(this));
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), address(this));
    }
}
