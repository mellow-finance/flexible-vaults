// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/DeployVaultFactory.sol";
import "../common/DeployVaultFactoryRegistry.sol";
import "../common/OracleSubmitterFactory.sol";

import "./DeployAbstractScript.s.sol";

contract Deploy is DeployAbstractScript {
    using Math for uint256;

    address[] swapModuleAssets;

    function run() external {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        deployVault = Constants.deployVaultFactory;

        /// @dev just on-chain simulation
        //_simulate();

        /// @dev on-chain transaction
        //  if vault == address(0) -> step one
        //  else -> step two
        /// @dev fill in Vault address to run stepTwo
        vault = Vault(payable(address(0x20d87dd5D89F04B37Ac5077b80d66022edde505C)));

        testMintLP(123.45678 ether, 1e5);
        //_run();
        revert("ok");
    }

    function testMintLP(uint256 targetShares, uint256 actualDeposit) internal {
        uint224 targetPriceD18 = uint224(targetShares.mulDiv(1e18, actualDeposit));
        uint224 originalPriceD18 = vault.oracle().getReport(Constants.BTC).priceD18;
        uint224 currentPriceD18 = originalPriceD18;
        console.log("Current price:", currentPriceD18);
        console.log(" Target price:", targetPriceD18);

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        IOracle.Report[] memory reports = new IOracle.Report[](1);
        IOracle oracle = vault.oracle();
        IOracle.SecurityParams memory securityParams = oracle.securityParams();
        while (currentPriceD18 < targetPriceD18) {
            uint256 relativeDeviationD18 = uint256(targetPriceD18).mulDiv(1 ether, currentPriceD18);
            if (relativeDeviationD18 > securityParams.maxRelativeDeviationD18) {
                relativeDeviationD18 = securityParams.maxRelativeDeviationD18 > 10 ether
                    ? 10 ether
                    : securityParams.maxRelativeDeviationD18;
            }
            currentPriceD18 = uint224(uint256(currentPriceD18).mulDiv(relativeDeviationD18, 1e18));
            console.log("New price:", currentPriceD18);
            reports[0] = IOracle.Report({asset: Constants.BTC, priceD18: currentPriceD18});
            oracle.submitReports(reports);
            skip(securityParams.timeout + 1);
        }

        address account = vm.addr(deployerPk);
        IShareManager shareManager = vault.shareManager();
        DepositQueue BTCDepositQueue = DepositQueue(vault.queueAt(Constants.BTC, 1));
        BTCDepositQueue.deposit{value: actualDeposit}(uint224(actualDeposit), address(0), new bytes32[](0));
        vault.claimShares(account);
        uint256 actualShares = shareManager.sharesOf(account);
        assertApproxEqAbs(actualShares, targetShares, 1, "Unexpected actual shares minted");

        skip(securityParams.timeout + 1);
        reports[0] = IOracle.Report({asset: Constants.BTC, priceD18: originalPriceD18});
        oracle.submitReports(reports);

        assertEq(vault.oracle().getReport(Constants.BTC).priceD18, originalPriceD18, "Price should be back to original");
        vm.stopBroadcast();
    }

    function testDeposit() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        address account = vm.addr(deployerPk);
        // vault.setQueueLimit(100);
        // address[] memory assets = new address[](1);
        // assets[0] = Constants.BTC;
        // vault.oracle().addSupportedAssets(assets);
        //vault.createQueue(uint256(DepositQueueVersion.DEFAULT), true, proxyAdmin, Constants.BTC, "");
        //vault.oracle().setSecurityParams(
        //    IOracle.SecurityParams({
        //        maxAbsoluteDeviation: type(uint224).max,
        //        suspiciousAbsoluteDeviation: type(uint224).max,
        //        maxRelativeDeviationD18: type(uint64).max,
        //        suspiciousRelativeDeviationD18: type(uint64).max,
        //        timeout: 1,
        //        depositInterval: 1,
        //        redeemInterval: 1
        //    })
        //);
        IOracle.Report[] memory reports = new IOracle.Report[](2);
        reports[0] = IOracle.Report({asset: Constants.mcbBTC, priceD18: 1e28});
        reports[1] = IOracle.Report({asset: Constants.BTC, priceD18: 1e18});
        //   vault.oracle().submitReports(reports);
        require(vault.oracle().getReport(Constants.mcbBTC).isSuspicious == false, "Report not submitted correctly");
        require(vault.oracle().getReport(Constants.BTC).isSuspicious == false, "Report not submitted correctly");

        //vault.createQueue(uint256(RedeemQueueVersion.DEFAULT), false, proxyAdmin, Constants.BTC, "");

        // BTC 0.0000000000001 * 1e18 = 1e5 ts 1770706603
        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = 1770706603;
        address BTCRedeemQueue = vault.queueAt(Constants.BTC, 2);
        //RedeemQueue(payable(BTCRedeemQueue)).redeem(vault.shareManager().sharesOf(account));
        RedeemQueue(payable(BTCRedeemQueue)).handleBatches(10);
        uint256 assets = RedeemQueue(payable(BTCRedeemQueue)).claim(account, timestamps);
        require(assets > 0, "Claim failed");

        // mcbBTC 0.0000001 * 1e18 = 1e11 ts 1770706101
        //uint32[] memory timestamps = new uint32[](1);
        //timestamps[0] = 1770706101;
        //address mcbBTCRedeemQueue = vault.queueAt(Constants.mcbBTC, 1);
        //RedeemQueue(payable(mcbBTCRedeemQueue)).handleBatches(10);
        //uint256 assets = RedeemQueue(payable(mcbBTCRedeemQueue)).claim(account, timestamps);
        //require(assets > 0, "Claim failed");
        //RedeemQueue(payable(mcbBTCRedeemQueue)).redeem(1e11);
        //vault.claimShares(account);
        return;
        //vault.createQueue(uint256(DepositQueueVersion.SYNC), true, proxyAdmin, Constants.BTC, abi.encode(0, 365 days));

        //address BTCDepositQueue = vault.queueAt(Constants.BTC, 1);
        //DepositQueue(BTCDepositQueue).deposit{value: 1e5}(1e5, address(0), new bytes32[](0));

        //address mcbBTCDepositQueue = vault.queueAt(Constants.mcbBTC, 2);
        //IERC20(Constants.mcbBTC).approve(mcbBTCDepositQueue, 1e1);
        //DepositQueue(mcbBTCDepositQueue).deposit(1e1, address(0), new bytes32[](0));
    }

    function setUp() public override {
        isEmptyVault = true;
        deployOracleSubmitter = false;
        /// @dev fill name and symbol
        vaultName = "Mezo test Vault";
        vaultSymbol = "mtestVault";

        address testMsig = 0x0b20d72e436FB2820EE1338d93AA676A6c2e79F4; // 1/2 deployer msig for testing
        /// @dev fill admin/operational addresses
        proxyAdmin = testMsig;
        lazyVaultAdmin = testMsig;
        activeVaultAdmin = testMsig;
        curator = testMsig;
        feeManagerOwner = testMsig;
        pauser = testMsig;
        oracleUpdater = testMsig;

        timelockProposers = new address[](1);
        timelockProposers[0] = lazyVaultAdmin;
        timelockExecutors = new address[](2);
        timelockExecutors[0] = lazyVaultAdmin;
        timelockExecutors[1] = pauser;

        /// @dev fill fee parameters
        depositFeeD6 = 0;
        redeemFeeD6 = 0;
        performanceFeeD6 = 0;
        protocolFeeD6 = 0;

        /// @dev fill security params
        securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: type(uint224).max,
            suspiciousAbsoluteDeviation: type(uint224).max,
            maxRelativeDeviationD18: type(uint64).max,
            suspiciousRelativeDeviationD18: type(uint64).max,
            timeout: 1,
            depositInterval: 1,
            redeemInterval: 1
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

        subvaultParams[0].assets = new address[](2);
        subvaultParams[0].assets[0] = Constants.BTC;
        subvaultParams[0].assets[1] = Constants.mcbBTC;
        subvaultParams[0].version = uint256(SubvaultVersion.DEFAULT);
        subvaultParams[0].verifierVersion = 0;
        subvaultParams[0].limit = type(int256).max;
    }

    /// @dev fill in queue parameters
    function getQueues()
        internal
        pure
        override
        returns (IDeployVaultFactory.QueueParams[] memory queues, uint256 queueLimit)
    {
        queues = new IDeployVaultFactory.QueueParams[](50);
        uint256 index;
        // default
        {
            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(DepositQueueVersion.DEFAULT),
                isDeposit: true,
                asset: Constants.BTC,
                data: ""
            });

            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(RedeemQueueVersion.DEFAULT),
                isDeposit: false,
                asset: Constants.BTC,
                data: ""
            });

            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(DepositQueueVersion.DEFAULT),
                isDeposit: true,
                asset: Constants.mcbBTC,
                data: ""
            });

            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(RedeemQueueVersion.DEFAULT),
                isDeposit: false,
                asset: Constants.mcbBTC,
                data: ""
            });
        }

        // sync deposit and redeem queues for BTC
        {
            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(DepositQueueVersion.SYNC),
                isDeposit: true,
                asset: Constants.BTC,
                data: abi.encode(0, 365 days)
            });

            queues[index++] = IDeployVaultFactory.QueueParams({
                version: uint256(DepositQueueVersion.SYNC),
                isDeposit: true,
                asset: Constants.mcbBTC,
                data: abi.encode(0, 365 days)
            });
        }

        assembly {
            mstore(queues, index)
        }

        queueLimit = queues.length;
    }

    /// @dev fill in allowed assets/base asset and subvault assets
    function getAssetsWithPrices()
        internal
        pure
        override
        returns (address[] memory allowedAssets, uint224[] memory allowedAssetsPrices)
    {
        allowedAssets = new address[](2);
        allowedAssetsPrices = new uint224[](2);
        allowedAssets[0] = Constants.BTC;
        allowedAssets[1] = Constants.mcbBTC;
        allowedAssetsPrices[0] = 1 ether;
        allowedAssetsPrices[1] = 1 ether;
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
        console.log("Deployed SwapModule at", swapModule);
        vm.stopBroadcast();
        return swapModule;
    }
}
