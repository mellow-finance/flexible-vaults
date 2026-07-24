// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        // Arc is a fresh chain: deploy the registry + oracle submitter factory + deploy vault factory.
        deployVault = IDeployVaultFactory(0x1c28072D580C1f154108e3E909808dbfb5Ac576B); // deployNewDeployVault();
        //  revert("success");

        /// @dev Vault mocked for now — un-stub and follow the two-step flow when ready:
        ///   - step one: run with vault == address(0) to deploy the vault
        ///   - step two: set `vault` to the deployed address and re-run to finalize
        vault = Vault(payable(address(0x258D0b0DF06Cdee94C175dc617b99735f549FDCF)));
        _run();
        //_simulate();
    }

    function deployNewDeployVault() internal returns (IDeployVaultFactory deployVault) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        vm.startBroadcast(deployerPk);
        DeployVaultFactoryRegistry registry = new DeployVaultFactoryRegistry();
        OracleSubmitterFactory oracleSubmitterFactory = new OracleSubmitterFactory();
        deployVault = new DeployVaultFactory(
            address($.vaultConfigurator), address($.verifierFactory), address(oracleSubmitterFactory), address(registry)
        );
        vm.stopBroadcast();

        console.log("OracleSubmitterFactory     %s", address(oracleSubmitterFactory));
        console.log("DeployVaultFactoryRegistry %s", address(registry));
        console.log("DeployVaultFactory         %s", address(deployVault));
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "test KeyRock Arc";
        vaultSymbol = "tKRArc";
        address mellowTempAdmin = 0x23EB74357FaD0bf8e430Bd52ff424dB9997f0744; // deployer

        /// @dev fill admin/operational addresses
        proxyAdmin = mellowTempAdmin;
        lazyVaultAdmin = mellowTempAdmin;
        activeVaultAdmin = mellowTempAdmin;
        oracleUpdater = mellowTempAdmin;
        curator = mellowTempAdmin;
        feeManagerOwner = mellowTempAdmin;
        pauser = mellowTempAdmin;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0; // 0%
        protocolFeeD6 = 0; // 0%

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            // strict params to avoid price deviations
            maxAbsoluteDeviation: 1,
            suspiciousAbsoluteDeviation: 1,
            maxRelativeDeviationD18: 1,
            suspiciousRelativeDeviationD18: 1,
            timeout: 1 seconds,
            depositInterval: 1 seconds, // does not affect sync deposit queue
            redeemInterval: 1 seconds // almost all redeems will be handled in the same report as they are not delayed, so redeem interval can be the same as timeout
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = 1e8 ether; // 100M USDC

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0; // TokenizedShareManager, impl: 0x0000000E8eb7173fA1a3ba60eCA325bcB6aaf378
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
        subvaultParams = new IDeployVaultFactory.SubvaultParams[](1);

        subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = 1e8 ether; // 100M USDC
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        /*
        D0 DepositQueue
        D1 SignatureDepositQueue
        D2 SyncDepositQueue
        R0 RedeemQueue
        R1 SignatureRedeemQueue
        */
        queues = new IDeployVaultFactory.QueueParams[](2);

        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(2),
            isDeposit: true,
            asset: Constants.USDC,
            data: abi.encode(uint256(0), uint32(365 days)) // penaltyD6, maxAge for SyncDepositQueue
        });

        queues[1] =
            IDeployVaultFactory.QueueParams({version: uint256(0), isDeposit: false, asset: Constants.USDC, data: ""});

        queueLimit = 2;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.EURC));
        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = uint224(1e30); // USDC 6 decimals
        allowedAssetsPrices[1] = uint224(1e30); // EURC 6 decimals
    }

    /// @dev fill in vault role holders
    function getVaultRoleHolders(address timelockController, address oracleSubmitter)
        internal
        view
        override
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](50);

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

        assembly {
            mstore(holders, index)
        }
    }

    /// @dev fill in merkle roots
    function getSubvaultMerkleRoot(uint256 index)
        internal
        override
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {}
}
