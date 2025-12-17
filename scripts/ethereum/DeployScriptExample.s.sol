// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    bytes32 public testWalletPk = keccak256("testWalletPk");
    address public testWallet = vm.addr(uint256(testWalletPk));

    function run() external {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = $.deployVaultFactory;

        /// @dev just on-chain simulation
        _simulate();
        revert("ok");

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0)));
        _run();
        revert("ok");
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "testDeploy";
        vaultSymbol = "tDEP";

        /// @dev fill admin/operational addresses
        proxyAdmin = testWallet;
        lazyVaultAdmin = testWallet;
        activeVaultAdmin = testWallet;
        oracleUpdater = testWallet;
        curator = testWallet;
        feeManagerOwner = testWallet;
        pauser = testWallet;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 1e5;
        protocolFeeD6 = 1e4;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.005 ether,
            suspiciousAbsoluteDeviation: 0.001 ether,
            maxRelativeDeviationD18: 0.005 ether,
            suspiciousRelativeDeviationD18: 0.001 ether,
            timeout: 20 hours,
            depositInterval: 1 hours,
            redeemInterval: 2 days
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = type(int256).max / 2;

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0;
        feeManagerVersion = 0;
        riskManagerVersion = 0;
        oracleVersion = 0;
    }

    /// @dev fill in subvault parameters
    function getSubvaultParams()
        internal
        pure
        override
        returns (IDeployVaultFactory.SubvaultParams[] memory subvaultParams)
    {
        subvaultParams = new IDeployVaultFactory.SubvaultParams[](2);

        subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = type(int256).max / 2;

        subvaultParams[1].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.STETH, Constants.WSTETH));
        subvaultParams[1].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[1].verifierVersion = 0;
        subvaultParams[1].limit = type(int256).max / 2;
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        address[] memory depositQueueAssets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.STETH, Constants.WSTETH));
        address[] memory redeemQueueAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH));

        queues = new IDeployVaultFactory.QueueParams[](depositQueueAssets.length + redeemQueueAssets.length);
        for (uint256 i = 0; i < depositQueueAssets.length; i++) {
            queues[i] = IDeployVaultFactory.QueueParams({
                version: uint256(QueueVersion.DEFAULT),
                isDeposit: true,
                asset: depositQueueAssets[i],
                data: ""
            });
        }
        for (uint256 i = 0; i < redeemQueueAssets.length; i++) {
            queues[depositQueueAssets.length + i] = IDeployVaultFactory.QueueParams({
                version: uint256(QueueVersion.DEFAULT),
                isDeposit: false,
                asset: redeemQueueAssets[i],
                data: ""
            });
        }

        /// @dev fill, override if needed
        queueLimit = queues.length;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.STETH, Constants.WSTETH));

        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = 1 ether;
        allowedAssetsPrices[1] = 1 ether;
        allowedAssetsPrices[2] = 1 ether;
        allowedAssetsPrices[3] = 1 ether;
    }

    /// @dev fill in vault role holders
    function getVaultRoleHolders(address timelockController, address oracleSubmitter)
        internal
        view
        override
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](16 + (timelockController == address(0) ? 0 : 3));

        // lazyVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_SECURITY_PARAMS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        if (timelockController != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
            holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, timelockController);
        }

        // oracle submitter roles:
        if (oracleSubmitter != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, oracleSubmitter);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleSubmitter);
        } else {
            holders[index++] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
            holders[index++] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);
        }

        // curator roles:
        holders[index++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[index++] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);
    }

    /// @dev fill in merkle roots
    function getSubvaultMerkleRoot(Vault vault, uint256 index) internal view override returns (bytes32 merkleRoot) {
        Subvault subvault = Subvault(payable(vault.subvaultAt(index)));

        merkleRoot = bytes32(0);
    }
}
