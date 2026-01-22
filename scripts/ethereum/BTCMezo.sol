// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ArraysLibrary.sol";

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";
import "../common/ProofLibrary.sol";
import "./DeployAbstractScript.s.sol";
import {mezoBTCLibrary} from "./mezoBTCLibrary.sol";

contract Deploy is DeployAbstractScript {
    bytes32 public testWalletPk = keccak256("testWalletPk");
    address public testWallet = vm.addr(uint256(testWalletPk));

    function run() external {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = Constants.deployVaultFactory;

        /// @dev just on-chain simulation
        //_simulate();
        //revert("ok");

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0xa8A3De0c5594A09d0cD4C8abc4e3AaB9BaE03F36)));
        getSubvaultMerkleRoot(0);
        ////revert("ok");
        //_run();
        revert("ok");
    }

    function deposit(address asset, address queue) internal {
        IDepositQueue depositQueue = IDepositQueue(queue);
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);
        uint224 amount = uint224(IERC20(asset).balanceOf(deployer)) / 2;
        IERC20(asset).approve(address(depositQueue), amount);
        depositQueue.deposit(amount, address(0), new bytes32[](0));
        ShareManager shareManager = ShareManager(payable(0x43f084bdBC99409c637319dD7c544D565165A162));
        console.log(
            "%s %s deposited, shares received:", IERC20Metadata(asset).symbol(), amount, shareManager.sharesOf(deployer)
        );
        vm.stopBroadcast();
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "Mezo Bitcoin Home BTC Vault";
        vaultSymbol = "mbhBTC";

        /// @dev fill admin/operational addresses
        proxyAdmin = 0xd5aA2D083642e8Dec06a5e930144d0Af5a97496d; // 3/5
        lazyVaultAdmin = 0xd5aA2D083642e8Dec06a5e930144d0Af5a97496d; // 3/5
        activeVaultAdmin = 0xF912FdB104dFE5baF2a6f1C4778Bc644E89Aa458; // 2/3
        oracleUpdater = 0xa68b023D9ed2430E3c8cBbdE4c37b02467734c33; // 1/1 msig 0xF6edb1385eC1A61c33B9e8dcc348497dCceabE8D
        curator = 0x7dF72E9BBD03D8c6FAf41C0dd8CE46be2878C6Fa; // 1/1 msig 0x57775cB0C39671487981706FFb1D3B3ff65Ebb1f
        feeManagerOwner = 0xb7b2ee53731Fc80080ED2906431e08452BC58786; // Mellow+Sense 5/4+4
        pauser = 0xF912FdB104dFE5baF2a6f1C4778Bc644E89Aa458; // 2/3

        timelockProposers = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin));
        timelockExecutors = ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin, pauser));

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0;
        protocolFeeD6 = 0;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 0.005 ether,
            suspiciousAbsoluteDeviation: 0.001 ether,
            maxRelativeDeviationD18: 0.005 ether,
            suspiciousRelativeDeviationD18: 0.001 ether,
            timeout: 20 hours,
            depositInterval: 1 hours, // does not affect sync deposit queue
            redeemInterval: 365 days // no redemptions allowed
        });

        ProtocolDeployment memory $ = Constants.protocolDeployment();

        /// @dev fill default hooks
        defaultDepositHook = address($.redirectingDepositHook);
        defaultRedeemHook = address($.basicRedeemHook);

        /// @dev fill share manager params
        shareManagerWhitelistMerkleRoot = bytes32(0);

        /// @dev fill risk manager params
        riskManagerLimit = 100 ether; // 100 BTC

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

        subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.TBTC, Constants.WBTC));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = 100 ether; // 100 BTC
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
            version: uint256(QueueVersion.SYNC),
            isDeposit: true,
            asset: Constants.TBTC,
            data: abi.encode(uint256(0), 365 days) // penaltyD6 = 0%, maxAge = maximum
        });

        queues[1] = IDeployVaultFactory.QueueParams({
            version: uint256(QueueVersion.SYNC),
            isDeposit: true,
            asset: Constants.WBTC,
            data: abi.encode(uint256(0), 365 days) // penaltyD6 = 0%, maxAge = maximum
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
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.TBTC, Constants.WBTC));

        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = 1 ether; // 18 decimals
        allowedAssetsPrices[1] = 1e28; // 8 decimals
    }

    /// @dev fill in vault role holders
    function getVaultRoleHolders(address timelockController, address oracleSubmitter)
        internal
        view
        override
        returns (Vault.RoleHolder[] memory holders)
    {
        uint256 index;
        holders = new Vault.RoleHolder[](15 + (timelockController == address(0) ? 0 : 3));

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
    function getSubvaultMerkleRoot(uint256 index)
        internal
        override
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        Subvault subvault = Subvault(payable(vault.subvaultAt(index)));
        (address swapModule, address[] memory swapModuleAssets) = _deploySwapModule(address(subvault));

        mezoBTCLibrary.Info memory info = mezoBTCLibrary.Info({
            curator: curator,
            subvault: address(subvault),
            swapModule: swapModule,
            subvaultName: "subvault0",
            swapModuleAssets: swapModuleAssets,
            positionManager: Constants.UNISWAP_V4_POSITION_MANAGER,
            uniswapV4Assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.TBTC, Constants.WBTC))
        });
        IVerifier.VerificationPayload[] memory leaves;

        (merkleRoot, leaves) = mezoBTCLibrary.getBTCSubvault0Proofs(info);

        string[] memory descriptions = mezoBTCLibrary.getBTCSubvault0Descriptions(info);
        ProofLibrary.storeProofs("ethereum:mbhBTC:subvault0", merkleRoot, leaves, descriptions);

        calls = mezoBTCLibrary.getBTCSubvault0Calls(info, leaves);

        _runChecks(subvault.verifier(), calls);
    }

    function _runChecks(IVerifier verifier, SubvaultCalls memory calls) internal view {
        for (uint256 i = 0; i < calls.payloads.length; i++) {
            AcceptanceLibrary._verifyCalls(verifier, calls.calls[i], calls.payloads[i]);
        }
    }

    function _deploySwapModule(address subvault) internal returns (address swapModule, address[] memory assets) {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[2] memory tokens = [Constants.TBTC, Constants.WBTC];
        address[] memory actors = ArraysLibrary.makeAddressArray(abi.encode(curator, tokens, tokens));
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE
            )
        );

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        vm.stopBroadcast();
        return (swapModule, ArraysLibrary.makeAddressArray(abi.encode(tokens)));
    }
}
