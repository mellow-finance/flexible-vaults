// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";

import {TransferDepositHook} from "../../src/hooks/TransferDepositHook.sol";

contract Deploy is DeployAbstractScript {
    function run() external {
        deployVault = IDeployVaultFactory(0x9cbD8a4033fDa06809B5e0056287b512Bbf579Ef); //deployNewDeployVault();//

        /// @dev just on-chain simulation
        // _simulate();

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0x5596c367d808A8c0AB40F3799ee8d97f37a10Ee5)));
        // _run();
        // return;
        //deposit(Constants.USDC, address(0x4B4977D887056cD6C45D73F697eB6C49eF0da764));
        // _deploySwapModule(vault.subvaultAt(0));
        // _deploySwapModule(vault.subvaultAt(1));
        _deployTransferDepositHook();
        //revert("ok");
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
        //isEmptyVault = true;
        vaultName = "test KeyRock #3-2";
        vaultSymbol = "tKR3-2";
        // 0xc79829aF88e34a229a2C573c170e0619AFF9d64A keyrock Tim
        // 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3 andrei
        // 0x4d551d74e851Bd93Ce44D5F588Ba14623249CDda my
        address msig = 0x039db8459715b3797C4dfff26C3Ab036460ec500;
        /// @dev fill admin/operational addresses
        proxyAdmin = msig;
        lazyVaultAdmin = msig;
        activeVaultAdmin = msig;
        oracleUpdater = msig;
        curator = msig;
        feeManagerOwner = msig;
        pauser = msig;

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0;
        protocolFeeD6 = 0;

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
        riskManagerLimit = 1e10 ether; // 1e10 ETH

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
        subvaultParams[0].limit = 1e10 ether; // 1e10 ETH
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
            version: uint256(3),
            isDeposit: true,
            asset: Constants.USDC,
            data: abi.encode(uint256(0), uint32(365 days)) // penaltyD6, maxAge for SyncDepositQueue
        });

        queues[1] =
            IDeployVaultFactory.QueueParams({version: uint256(2), isDeposit: false, asset: Constants.USDC, data: ""});

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
        address[3] memory swapModuleAssets = [Constants.USDC, Constants.USPS, Constants.RLUSD];

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

    /// @dev Deploys a TransferDepositHook for this vault (sKRAA / tKR3-2).
    ///      On each processed deposit the hook (delegatecalled by the vault) pushes the assets into
    ///      subvault0 via hookPushAssets, then has subvault0 transfer them out to the external strategy
    ///      custody (ethereum_external_strategy). That USDC transfer is already whitelisted by
    ///      subvault0's verifier merkle root (see permission-builder tKR3-2.yaml: external_strategy/Custody).
    /// @dev The HOT_DEPLOYER only deploys the hook. To activate it, the msig (holder of SET_HOOK_ROLE)
    ///      must wire it on the ShareModule, e.g. setCustomHook(<sKRAA SyncDepositQueue>, hook)
    ///      or setDefaultDepositHook(hook).
    function _deployTransferDepositHook() internal returns (address hook) {
        // ethereum_external_strategy (Custody) — destination for forwarded deposits
        address externalStrategy = 0x6D9cA36bC9b0123A6bCaBDfd6aBed9c85Ec9453b;
        address subvault = vault.subvaultAt(0); // sKRAA_subvault_0 (0xbFa623fF4D60D86D33c8d6d5E1eBad7BcF44688C)

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        hook = address(new TransferDepositHook(Constants.USDC, address(vault), subvault, externalStrategy));
        console.log("TransferDepositHook (tKR3-2 -> external_strategy) at", hook);
        vm.stopBroadcast();

        // @dev simulation/fork only: impersonate the msig (DEFAULT_ADMIN_ROLE) to grant SET_HOOK_ROLE
        //      and wire the hook as the default deposit hook. On-chain this is executed by the msig
        //      multisig (not via vm.prank), e.g. grantRole(SET_HOOK_ROLE, msig) + setDefaultDepositHook(hook).
        vm.startPrank(lazyVaultAdmin);
        vault.grantRole(vault.SET_HOOK_ROLE(), lazyVaultAdmin);
        vault.setDefaultDepositHook(hook);
        vm.stopPrank();
        console.log("Default deposit hook set to", hook);

        return hook;
    }
}
