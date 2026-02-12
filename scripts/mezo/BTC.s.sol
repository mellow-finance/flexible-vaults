// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";

import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        GAS_PER_TRANSACTION = 1.0e7;
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = Constants.deployVaultFactory;

        /// @dev just on-chain simulation
        //_simulate();

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0x807D4778abA870e4222904f5b528F68B350cE0E0)));

        //revert("ok");

        _run();
        // revert("ok");
    }

    function setUp() public override {
        isEmptyVault = false;
        deployOracleSubmitter = true;
        /// @dev fill name and symbol
        vaultName = "Mezo Bitcoin Home BTC Vault";
        vaultSymbol = "mbhBTC";

        /// @dev fill admin/operational addresses
        proxyAdmin = 0xb7b2ee53731Fc80080ED2906431e08452BC58786; // 5/8 Mellow+Mezo
        lazyVaultAdmin = 0xd5aA2D083642e8Dec06a5e930144d0Af5a97496d; // 3/5 Mezo
        activeVaultAdmin = 0xF912FdB104dFE5baF2a6f1C4778Bc644E89Aa458; // 2/3 Mezo
        curator = 0x7dF72E9BBD03D8c6FAf41C0dd8CE46be2878C6Fa; // 1/1 msig 0x57775cB0C39671487981706FFb1D3B3ff65Ebb1f Mezo
        feeManagerOwner = 0xb7b2ee53731Fc80080ED2906431e08452BC58786; // Mellow+Sense 5/4+4 Mezo
        pauser = 0xF912FdB104dFE5baF2a6f1C4778Bc644E89Aa458; // 2/3
        oracleUpdater = 0xd5aA2D083642e8Dec06a5e930144d0Af5a97496d; // just mock for DeployFactory

        timelockProposers = new address[](1);
        timelockProposers[0] = lazyVaultAdmin;
        timelockExecutors = new address[](2);
        timelockExecutors[0] = lazyVaultAdmin;
        timelockExecutors[1] = pauser;

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 100000; // 10% performance fee
        protocolFeeD6 = 10000; // 1% protocol fee

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 1,
            suspiciousAbsoluteDeviation: 1,
            maxRelativeDeviationD18: 1,
            suspiciousRelativeDeviationD18: 1,
            timeout: 365 days, // no timeout
            depositInterval: 365 days, // does not affect sync deposit queue
            redeemInterval: 365 days // no redemptions allowed
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address(0);
        defaultRedeemHook = address(0);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = type(int256).max;

        /// @dev fill versions
        vaultVersion = 0;
        shareManagerVersion = 0; // TokenizedShareManager
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

        // native BTC subvault (veBTC)
        {
            subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.BTC));
            subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
            subvaultParams[0].verifierVersion = 0;
            subvaultParams[0].limit = type(int256).max;
        }
        return subvaultParams;
        // MUSD subvault (mint/repay/borrow)
        {
            subvaultParams[1].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.BTC, Constants.MUSD));
            subvaultParams[1].version = uint256(SubvaultVersion.DEFAULT);
            subvaultParams[1].verifierVersion = 0;
            subvaultParams[1].limit = type(int256).max;
        }
        // Tigris subvault (LPing BTC/MUSD on Tigris AMM)
        {
            subvaultParams[2].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.BTC, Constants.MUSD));
            subvaultParams[2].version = uint256(SubvaultVersion.DEFAULT);
            subvaultParams[2].verifierVersion = 0;
            subvaultParams[2].limit = type(int256).max;
        }
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        queues = new IDeployVaultFactory.QueueParams[](1);
        queueLimit = 1;
        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(DepositQueueVersion.DEFAULT),
            isDeposit: true,
            asset: Constants.BTC,
            data: ""
        });
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.BTC, Constants.MUSD));
        uint256 BTCPrice = 69000;
        allowedAssetsPrices = ArraysLibrary.makeUint224Array(abi.encode(1e18, 1e18 / BTCPrice));
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
        holders[index++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, lazyVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[index++] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[index++] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);

        // emergency pauser roles:
        if (timelockController != address(0)) {
            holders[index++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, timelockController);
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

    function _deploySwapModule(address subvault, address[] memory actors, bytes32[] memory permissions)
        internal
        returns (address swapModule)
    {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0,
            proxyAdmin,
            abi.encode(
                lazyVaultAdmin, subvault, address(0), /* Constants.AAVE_V3_ORACLE */ 0.995e8, actors, permissions
            )
        );
        console2.log("Deployed SwapModule at", swapModule);
        vm.stopBroadcast();
        return swapModule;
    }
}
