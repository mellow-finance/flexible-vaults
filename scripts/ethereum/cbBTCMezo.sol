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
    address[] uniswapV3Pools;
    bytes25[] uniswapV4Pools;
    bytes32 constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

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
        vault = Vault(payable(address(0x63a76a4a94cAB1DD49fcf0d7E3FC53a78AC8Ec5C)));
        //transferOwnership();
        //revert("ok");

        //uniswapV3Pools = ArraysLibrary.makeAddressArray(abi.encode(Constants.UNISWAP_V3_POOL_WBTC_CBBTC_100));
        uniswapV4Pools = ArraysLibrary.makeBytes25Array(abi.encode(Constants.UNISWAP_V4_POOL_TBTC_CBBTC_100));

        //uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        //vm.startBroadcast(deployerPk);
        //mezoBTCLibrary.mintTokenIdsV3(uniswapV3Pools, vault.subvaultAt(0));
        //mezoBTCLibrary.mintTokenIdsV4(uniswapV4Pools, vault.subvaultAt(0));
        //vm.stopBroadcast();
        //return;
        {
            // vm.startBroadcast(deployerPk);
            // address verifier = $.verifierFactory.create(0, proxyAdmin, abi.encode(vault, bytes32(0)));
            // console2.log("mbhcbBTC subvault1 Verifier deployed at:", verifier);
            // vm.stopBroadcast();
            // mbhcbBTC subvault1 Verifier deployed at: 0x577A106ABc361772fC825723A7CdfafDbb596ed1
            // address verifier = 0x577A106ABc361772fC825723A7CdfafDbb596ed1;
            // vm.startPrank(lazyVaultAdmin);
            // vault.grantRole(Permissions.CREATE_SUBVAULT_ROLE, lazyVaultAdmin);
            // vault.createSubvault(0, proxyAdmin, verifier);
            // vm.stopPrank();
        }

        getSubvaultMerkleRoot(0);
        //_run();
        revert("ok");
    }

    function transferOwnership() internal {
        /*
            proxyAdmin: Mellow Admin (⅝ sign) 0xb7b2ee53731Fc80080ED2906431e08452BC58786 EOA TLL MKG CWK + 4 mellow
            lazyVaultAdmin: Sense Admin (⅗ sign) 0xd5aA2D083642e8Dec06a5e930144d0Af5a97496d EOA TLL MKG CWK VVV
            activeVaultAdmin: Sense Op (⅔ sign) 0xF912FdB104dFE5baF2a6f1C4778Bc644E89Aa458 EOA TLL MGK
            oracleUpdater: Oracle Update (1/1 sign) 0xa68b023D9ed2430E3c8cBbdE4c37b02467734c33 (0xF6edb1385eC1A61c33B9e8dcc348497dCceabE8D EOA)
            curator: Curator (1/1 sign) 0x7dF72E9BBD03D8c6FAf41C0dd8CE46be2878C6Fa (0x57775cB0C39671487981706FFb1D3B3ff65Ebb1f EOA)
        */
        address newProxyAdmin = 0xb7b2ee53731Fc80080ED2906431e08452BC58786;
        // new proxy admin for the Vault
        setNewOwner(address(vault), proxyAdmin, newProxyAdmin, "vault");
        // new proxy admin for the ShareManager
        setNewOwner(address(vault.shareManager()), proxyAdmin, newProxyAdmin, "shareManager");
        // new proxy admin for the FeeManager
        setNewOwner(address(vault.feeManager()), proxyAdmin, newProxyAdmin, "feeManager");
        // new proxy admin for the RiskManager
        setNewOwner(address(vault.riskManager()), proxyAdmin, newProxyAdmin, "riskManager");
        // new proxy admin for the Oracle
        setNewOwner(address(vault.oracle()), proxyAdmin, newProxyAdmin, "oracle");

        // new proxy admin for subvaults and queues
        for (uint256 i = 0; i < vault.subvaults(); i++) {
            setNewOwner(vault.subvaultAt(i), proxyAdmin, newProxyAdmin, "subvault");
        }
        // new proxy admin for queues
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                setNewOwner(vault.queueAt(asset, j), proxyAdmin, newProxyAdmin, "queue");
            }
        }
        proxyAdmin = newProxyAdmin;
    }

    function setNewOwner(address proxy, address oldProxyAdmin, address newProxyAdmin, string memory name) internal {
        ProxyAdmin admin = ProxyAdmin(address(uint160(uint256(vm.load(proxy, ADMIN_SLOT)))));
        if (admin.owner() == newProxyAdmin) {
            return;
        }

        assertTrue(admin.owner() == oldProxyAdmin, "Unexpected old ProxyAdmin");
        vm.startPrank(oldProxyAdmin);
        admin.transferOwnership(newProxyAdmin);
        vm.stopPrank();
        assertEq(admin.owner(), newProxyAdmin, "Unexpected new ProxyAdmin");
        console2.log("ProxyAdmin %s of proxy %s (%s)", address(admin), proxy, name);
        console2.logBytes(abi.encodeCall(Ownable.transferOwnership, (newProxyAdmin)));
    }

    function deposit(address asset, address queue) internal {
        IDepositQueue depositQueue = IDepositQueue(queue);
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);
        uint224 amount = uint224(IERC20(asset).balanceOf(deployer)) / 2;
        IERC20(asset).approve(address(depositQueue), amount);
        depositQueue.deposit(amount, address(0), new bytes32[](0));
        ShareManager shareManager = ShareManager(payable(0x171b8E43bB751A558b2b1f3C814d3c96D36cCf2B));
        console.log(
            "%s %s deposited, shares received:", IERC20Metadata(asset).symbol(), amount, shareManager.sharesOf(deployer)
        );
    }

    function setUp() public override {
        /// @dev fill name and symbol
        vaultName = "Mezo Bitcoin Home cbBTC Vault";
        vaultSymbol = "mbhcbBTC";

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
        riskManagerLimit = 50 ether; // 50 cbBTC

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
        subvaultParams = new IDeployVaultFactory.SubvaultParams[](2);

        subvaultParams[0].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.CBBTC));
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = 50 ether; // 50 cbBTC

        subvaultParams[1].assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.CBBTC));
        subvaultParams[1].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[1].verifierVersion = 0;
        subvaultParams[1].limit = 50 ether; // 50 cbBTC
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        queues = new IDeployVaultFactory.QueueParams[](1);
        queues[0] = IDeployVaultFactory.QueueParams({
            version: uint256(QueueVersion.SYNC),
            isDeposit: true,
            asset: Constants.CBBTC,
            data: abi.encode(uint256(0), 365 days) // penaltyD6 = 0%, maxAge = maximum
        });
        queueLimit = 1;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.CBBTC));

        allowedAssetsPrices = new uint224[](allowedAssets.length);
        allowedAssetsPrices[0] = 1e28;
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

    function getTokenIdsV4(bytes25[] memory pools) internal pure returns (uint256[] memory tokenIds) {
        /* there is no way to fetch tokenIds belongs to subvault
            Minting Uniswap V4 positions at pool tBTC/cbBTC
            Minted Uniswap V4 tokenId: 143354 [-230316, -230216]
            Minted Uniswap V4 tokenId: 143355 [-230291, -230241]
            Minted Uniswap V4 tokenId: 143356 [-230316, -230266]
            Minted Uniswap V4 tokenId: 143357 [-230266, -230216]
        */
        tokenIds = new uint256[](4);
        tokenIds[0] = 143354;
        tokenIds[1] = 143355;
        tokenIds[2] = 143356;
        tokenIds[3] = 143357;
        return tokenIds;
    }

    /// @dev fill in merkle roots
    function getSubvaultMerkleRoot(uint256 index)
        internal
        override
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        Subvault subvault = Subvault(payable(vault.subvaultAt(index)));
        IVerifier verifier = subvault.verifier();

        IVerifier.VerificationPayload[] memory leaves;
        string[] memory descriptions;
        string memory jsonSubvaultName;

        if (index == 0) {
            (merkleRoot, leaves, descriptions, calls, jsonSubvaultName) = _getSubvault0MerkleRoot(address(subvault));
        } else if (index == 1) {
            (merkleRoot, leaves, descriptions, calls, jsonSubvaultName) = _getSubvault1MerkleRoot(address(subvault));
        } else {
            revert("Invalid subvault index");
        }

        ProofLibrary.storeProofs(jsonSubvaultName, merkleRoot, leaves, descriptions);

        vm.prank(lazyVaultAdmin);
        verifier.setMerkleRoot(merkleRoot);

        AcceptanceLibrary.runVerifyCallsChecks(verifier, calls);
    }

    function _getSubvault0MerkleRoot(address subvault)
        private
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls,
            string memory jsonSubvaultName
        )
    {
        // allow to swap not allowed assets because of LPing
        address[2] memory swapModuleAssets = [Constants.CBBTC, Constants.TBTC];
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
        address swapModule = 0xeF0C3036A29d6d9d1EC7a8aEe1DbB885C488641A; // _deploySwapModule(subvault, actors, permissions);

        mezoBTCLibrary.Info0 memory info = mezoBTCLibrary.Info0({
            curator: curator,
            subvault: subvault,
            swapModule: swapModule,
            subvaultName: "subvault0",
            swapModuleAssets: ArraysLibrary.makeAddressArray(abi.encode(swapModuleAssets)),
            positionManagerV3: Constants.UNISWAP_V3_POSITION_MANAGER,
            uniswapV3Pools: uniswapV3Pools,
            positionManagerV4: Constants.UNISWAP_V4_POSITION_MANAGER,
            uniswapV4TokenIds: getTokenIdsV4(uniswapV4Pools)
        });

        IVerifier verifier = Subvault(payable(subvault)).verifier();

        (merkleRoot, leaves, descriptions, calls) = mezoBTCLibrary.getBTCSubvault0Data(info);
        jsonSubvaultName = "ethereum:mbhcbBTC:subvault0";
    }

    function _getSubvault1MerkleRoot(address subvault)
        private
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls,
            string memory jsonSubvaultName
        )
    {
        mezoBTCLibrary.Info1 memory info = mezoBTCLibrary.Info1({
            curator: curator,
            subvault: subvault,
            subvaultName: "subvault1",
            yieldBasisTokens: ArraysLibrary.makeAddressArray(abi.encode(Constants.YIELD_BASIS_CBBTC_TOKEN))
        });

        IVerifier verifier = Subvault(payable(subvault)).verifier();

        (merkleRoot, leaves, descriptions, calls) = mezoBTCLibrary.getBTCSubvault1Data(info);
        jsonSubvaultName = "ethereum:mbhcbBTC:subvault1";
    }

    function _deploySwapModule(address subvault, address[] memory actors, bytes32[] memory permissions)
        internal
        returns (address swapModule)
    {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;

        vm.startBroadcast(deployerPk);
        swapModule = swapModuleFactory.create(
            0, proxyAdmin, abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, 0.995e8, actors, permissions)
        );
        console2.log("Deployed SwapModule at", swapModule);
        vm.stopBroadcast();
        return swapModule;
    }
}
