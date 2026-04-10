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

        deployVault = IDeployVaultFactory(0x9cbD8a4033fDa06809B5e0056287b512Bbf579Ef);//deployNewDeployVault();//

        /// @dev just on-chain simulation
        //_simulate();
        //revert("ok");

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0x6C5430717c0e771cAD29bA8CbcaFd5119E2A3934)));
        _run();

        deposit(Constants.USDC, address(0x717BA1D7b2D98e0F84A62329d91021130107feBE));
        _deploySwapModule(vault.subvaultAt(0));
        //_deploySwapModule(vault.subvaultAt(1));
       // revert("ok");
    }

    function deployNewDeployVault() internal returns (IDeployVaultFactory deployVault) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        vm.startBroadcast(deployerPk);
        DeployVaultFactoryRegistry deployVaultFactoryRegistry = new DeployVaultFactoryRegistry();
        address oracleSubmitterFactory = 0x00000009918c4BC0829C93312b059E7F7Ba8C273;
        deployVault = new DeployVaultFactory(
            address($.vaultConfigurator),
            address($.verifierFactory),
            oracleSubmitterFactory,
            address(deployVaultFactoryRegistry)
        );
        vm.stopBroadcast();
    }

    function deposit(address asset, address queue) internal {
        string memory symbol;
        IDepositQueue depositQueue = IDepositQueue(queue);
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);
        uint224 amount;
        uint256 value;
        if (asset == Constants.ETH) {
            symbol = "ETH";
            value = 1 gwei;
            amount = uint224(value);
        } else {
            symbol = IERC20Metadata(asset).symbol();
            amount = uint224(IERC20(asset).balanceOf(deployer)) / 100;
            IERC20(asset).approve(address(depositQueue), amount);
        }
        depositQueue.deposit{value: value}(amount, address(0), new bytes32[](0));
        IShareManager shareManager = vault.shareManager();
        console.log("%s %s deposited, shares received:", symbol, amount, shareManager.sharesOf(deployer));
        vm.stopBroadcast();
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "test KeyRock";
        vaultSymbol = "tKR";

        /// @dev fill admin/operational addresses
        proxyAdmin = 0x8c5Ade692Ea92eba5d2787a68b5B375D0f4f4c88;
        lazyVaultAdmin = 0x8c5Ade692Ea92eba5d2787a68b5B375D0f4f4c88;
        activeVaultAdmin = 0x9dE42108A439d2bB0Ba110076f292c5DdDb8A0D7;
        oracleUpdater = 0x30545eF21791095dDAe537776d6e7FCc2dE07981;
        curator = 0x7565b2884d05cd6b304029B40aDEa22679660ED7;
        feeManagerOwner = 0x8c5Ade692Ea92eba5d2787a68b5B375D0f4f4c88;
        pauser = 0xdEb7081da6397a364146d61064815D8FD9b7A873;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0;
        protocolFeeD6 = 0;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: type(uint224).max / 2, // no price deviation limit
            suspiciousAbsoluteDeviation: type(uint224).max / 2,
            maxRelativeDeviationD18: type(uint64).max / 2,
            suspiciousRelativeDeviationD18: type(uint64).max / 2,
            timeout: 1 seconds,
            depositInterval: 1 seconds, // does not affect sync deposit queue
            redeemInterval: 1 seconds // no redemptions allowed
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = 100 ether; // 100 ETH

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
        subvaultParams[0].limit = 100 ether; // 100 ETH
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        queues = new IDeployVaultFactory.QueueParams[](2);

        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(QueueVersion.DEFAULT),
            isDeposit: true,
            asset: Constants.USDC,
            data: ""
        });

        queues[1] = IDeployVaultFactory.QueueParams({
            version: uint256(2),
            isDeposit: false,
            asset: Constants.USDC,
            data: "" // penaltyD6 = 0%, maxAge = maximum
        });

        queueLimit = 2;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));
        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = uint224(1e30); // 6 decimals
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

    function _deploySwapModule(address subvault) internal returns (address swapModule) {
        // allow to swap not allowed assets because of LPing
        address[2] memory swapModuleAssets = [Constants.USDT, Constants.USDC];

        address[] memory actors = ArraysLibrary.makeAddressArray(
            abi.encode(curator, swapModuleAssets, swapModuleAssets, Constants.KYBERSWAP_ROUTER)
        );
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        console.log("Subvault %s, SwapModule at", subvault, swapModule);
        vm.stopBroadcast();
        return swapModule;
    }
}
