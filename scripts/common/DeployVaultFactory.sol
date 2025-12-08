// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "scripts/common/interfaces/IDeployVaultFactory.sol";

import "src/vaults/Subvault.sol";

import "./Permissions.sol";
import "./interfaces/Imports.sol";

contract DeployVaultFactory is IDeployVaultFactory {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    VaultConfigurator public vaultConfigurator;
    Factory public verifierFactory;

    mapping(address => TimelockController) public timelockControllers;
    mapping(address => DeployVaultConfig) internal deployVaultConfig;
    mapping(address => address) internal deployer;

    constructor(address vaultConfigurator_, address verifierFactory_) {
        if (vaultConfigurator_ == address(0) || verifierFactory_ == address(0)) {
            revert ZeroAddress();
        }

        vaultConfigurator = VaultConfigurator(vaultConfigurator_);
        verifierFactory = Factory(verifierFactory_);
    }

    /// @inheritdoc IDeployVaultFactory
    function deployVault(DeployVaultConfig calldata $) external returns (Vault vault) {
        if ($.queueLimit < $.queues.length) {
            revert LengthMismatch();
        }
        VaultConfigurator.InitParams memory initParams = _getInitVaultParams(
            $,
            IOracle.SecurityParams({
                maxAbsoluteDeviation: 0.005 ether,
                suspiciousAbsoluteDeviation: 0.001 ether,
                maxRelativeDeviationD18: 0.005 ether,
                suspiciousRelativeDeviationD18: 0.001 ether,
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
        _pushReports(vault, $.allowedAssets, $.allowedAssetsPrices);

        // save config and allowed deployer for finalizeDeployment
        deployVaultConfig[address(vault)] = $;
        deployer[address(vault)] = msg.sender;
    }

    /// @inheritdoc IDeployVaultFactory
    function finalizeDeployment(Vault vault, SubvaultRoot[] memory subvaultRoots, Vault.RoleHolder[] memory holders)
        external
    {
        bool isDeployed = address(timelockControllers[address(vault)]) != address(0);
        if (isDeployed) {
            revert AlreadyInitialized();
        }

        DeployVaultConfig memory $ = deployVaultConfig[address(vault)];
        address baseAsset = $.allowedAssets[0];

        if (baseAsset == address(0)) {
            revert NotYetDeployed();
        }

        if (msg.sender != deployer[address(vault)]) {
            revert Forbidden();
        }

        // fee manager setup
        vault.feeManager().setBaseAsset(address(vault), baseAsset);
        Ownable(address(vault.feeManager())).transferOwnership($.feeManagerParams.owner);

        // create the rest of the queues
        _createQueues(vault, $.proxyAdmin, $.queues);

        // initial price reports
        _pushReports(vault, $.allowedAssets, $.allowedAssetsPrices);

        // set actual security params
        vault.oracle().setSecurityParams($.securityParams);

        // set subvault merkle roots
        _setSubvaultRoots(vault, subvaultRoots);

        // emergency pause setup
        TimelockController timelockController = _scheduleEmergencyPauses(vault, $);
        timelockControllers[address(vault)] = timelockController;

        // give roles to actual vault role holders
        _transferRoleHolders(vault, holders);

        delete deployVaultConfig[address(vault)];
    }

    /// @inheritdoc IDeployVaultFactory
    function getInitVaultParams(DeployVaultConfig memory $) public view returns (VaultConfigurator.InitParams memory) {
        return _getInitVaultParams($, $.securityParams);
    }

    function _getInitVaultParams(DeployVaultConfig memory $, IOracle.SecurityParams memory securityParams)
        internal
        view
        returns (VaultConfigurator.InitParams memory)
    {
        return VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: $.proxyAdmin,
            vaultAdmin: $.lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), $.vaultName, $.vaultSymbol),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(
                address(this),
                $.feeManagerParams.owner,
                $.feeManagerParams.depositFeeD6,
                $.feeManagerParams.redeemFeeD6,
                $.feeManagerParams.performanceFeeD6,
                $.feeManagerParams.protocolFeeD6
            ),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(securityParams, $.allowedAssets),
            defaultDepositHook: $.defaultDepositHook,
            defaultRedeemHook: $.defaultRedeemHook,
            queueLimit: $.queueLimit,
            /// @dev give full control to this for now
            roleHolders: _getTemporaryRoleHolders()
        });
    }

    function _createVault(VaultConfigurator.InitParams memory initParams) internal returns (Vault vault) {
        (,,,, address vault_) = vaultConfigurator.create(initParams);
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
            address verifier =
                verifierFactory.create($.subvaultParams[i].verifierVersion, $.proxyAdmin, abi.encode(vault, bytes32(0)));
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
            Subvault subvault = Subvault(payable(subvaultRoots[i].subvault));
            IVerifier verifier = subvault.verifier();
            verifier.setMerkleRoot(subvaultRoots[i].merkleRoot);
        }
    }

    function _scheduleEmergencyPauses(Vault vault, DeployVaultConfig memory $)
        internal
        returns (TimelockController timelockController)
    {
        address[] memory proposers = new address[](2);
        address[] memory executors = new address[](1);

        proposers[0] = $.lazyVaultAdmin;
        proposers[1] = address(this);
        executors[0] = $.lazyVaultAdmin;

        timelockController = new TimelockController(0, proposers, executors, $.lazyVaultAdmin);

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

    function _pushReports(Vault vault, address[] memory allowedAssets, uint256[] memory allowedAssetsPrices) internal {
        IOracle.Report[] memory reports = new IOracle.Report[](allowedAssets.length);
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            reports[i].asset = allowedAssets[i];
            reports[i].priceD18 = uint224(allowedAssetsPrices[i]);
        }

        IOracle oracle = vault.oracle();
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
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, address(this));
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, this_);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, this_);
    }

    function _transferRoleHolders(Vault vault, Vault.RoleHolder[] memory holders) internal {
        TimelockController timelockController = timelockControllers[address(vault)];

        // give roles to actual vault role holders
        for (uint256 i = 0; i < holders.length; i++) {
            vault.grantRole(holders[i].role, holders[i].holder);
        }

        // emergency pauser roles:
        vault.grantRole(Permissions.SET_FLAGS_ROLE, address(timelockController));
        vault.grantRole(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        vault.grantRole(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));

        // renounce roles from this contract
        Vault.RoleHolder[] memory temporaryHolders = _getTemporaryRoleHolders();
        for (uint256 i = 0; i < temporaryHolders.length; i++) {
            vault.renounceRole(temporaryHolders[i].role, address(this));
        }

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), address(this));
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), address(this));
    }
}
