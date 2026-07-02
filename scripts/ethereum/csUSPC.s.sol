// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    address internal constant customOracle = 0x4B30d453aA138CADFff8D4a9Cdb2503146FfF318; // with USPC

    function run() external {
        deployVault = IDeployVaultFactory(0x9cbD8a4033fDa06809B5e0056287b512Bbf579Ef); //deployNewDeployVault();//

        /// @dev just on-chain simulation
        //_simulate();
        //revert("ok");

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0xd3CcB5c59cDC8089DCE8e711c5da50A62572f422)));
        //_run();
        // deposit(Constants.USDC, address(0x94629C3b0A228E7C46a6D3E5ECBb4F68Cbc6Df43));
        _deploySwapModule(vault.subvaultAt(0));
       // revert("ok");
    }

    function deployNewDeployVault() internal returns (IDeployVaultFactory deployVault) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
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

    function deployMellowAccount(address proxyOwner, address owner, string memory name) internal returns (address mellowAccount) {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        mellowAccount = address($.accountFactory.create(0, proxyOwner, abi.encode(owner)));
        console.log("MellowAccount deployed at %s (%s)", mellowAccount, name);
        vm.stopBroadcast();
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "Coinshift USPC loop";
        vaultSymbol = "CsUSPC";
        address keyrokFordefi = 0xf1a9676B03Dd3B2066214D2aD8B4B59ED6642C53;
        address mellowTempAdmin = 0x5740175Dc9D57E7121A73A5BAa2A68BbA59503A4;
        
        /// @dev fill admin/operational addresses
        proxyAdmin = mellowTempAdmin;
        lazyVaultAdmin = 0xCd217F2DD550745f63F61528f061D6c98F728eDD; //deployMellowAccount(proxyAdmin, keyrokFordefi, "Lazy Vault Admin");
        activeVaultAdmin = 0xA2f404725007FfD4918Ea5552855959D334e02f3; //deployMellowAccount(proxyAdmin, keyrokFordefi, "Active Vault Admin");
        oracleUpdater = mellowTempAdmin;
        curator = 0x5582c12eFB3A47Fa2ea981bf28B8db881A36bf64; //deployMellowAccount(proxyAdmin, keyrokFordefi, "Curator");
        feeManagerOwner = mellowTempAdmin;
        pauser = mellowTempAdmin;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 1e5; // 10%
        protocolFeeD6 = 1e4; // 1%

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.005 * 1e30, // 0.5%
            suspiciousAbsoluteDeviation: 0.001 * 1e30, // 0.1%
            maxRelativeDeviationD18: 0.005 * 1e18, // 0.5%
            suspiciousRelativeDeviationD18: 0.001 * 1e18, // 0.1%
            timeout: 24 hours, // 24 hours
            depositInterval: 24 hours, // 24 hours
            redeemInterval: 48 hours // 48 hours
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

        subvaultParams[0].assets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USPC, Constants.RLUSD));
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
        queues = new IDeployVaultFactory.QueueParams[](3);

        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(QueueVersion.DEFAULT),
            isDeposit: true,
            asset: Constants.USDC,
            data: ""
        });

        queues[1] = IDeployVaultFactory.QueueParams({
            version: uint256(QueueVersion.SYNC), // SyncDepositQueue, impl: 0x000000000b98f77a017b5d3468400c5C597a3Bde
            isDeposit: true,
            asset: Constants.USDC,
            data: abi.encode(0, uint32(24 hours)) // (uint256 penaltyD6, uint32 maxAge)
        });

        queues[2] = IDeployVaultFactory.QueueParams({
            version: uint256(2),
            isDeposit: false,
            asset: Constants.USDC,
            data: ""
        });

        queueLimit = queues.length;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USPC, Constants.RLUSD));
        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = uint224(1e30); // USDC 6 decimals
        allowedAssetsPrices[1] = uint224(1e30); // USPC 6 decimals
        allowedAssetsPrices[2] = uint224(1e18); // RLUSD 18 decimals
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
        address[3] memory swapModuleAssets = [Constants.USDC, Constants.USPC, Constants.RLUSD];

        address[] memory actors = ArraysLibrary.makeAddressArray(
            abi.encode(curator, swapModuleAssets, swapModuleAssets, Constants.KYBERSWAP_ROUTER)
        );
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, customOracle, 0.995e8, actors, permissions)
        );
        console.log("Subvault %s, SwapModule at %s | oracle: %s", subvault, swapModule, customOracle);
        vm.stopBroadcast();
        return swapModule;
    }
}
