// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";

contract OracleHelperTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;

    OracleHelper oracleHelper;

    function setUp() external {
        oracleHelper = new OracleHelper();
    }

    /// @dev Test that the price calculation for the base asset is correct.
    /// Simple case: no fees, no pending withdrawals.
    function testPriceCalculationForBaseAsset(uint160 amount) external {
        vm.assume(amount > 0 && amount <= 100e18);

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](1);
        assets[0] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        addRedeemQueue(deployment, vaultProxyAdmin, assetAddress);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assetAddress));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), assetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 userShares = deployment.shareManager.sharesOf(user);
        uint256 totalShares = deployment.shareManager.totalShares();
        assertEq(userShares, totalShares, "User shares should be equal to total shares");

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
        assertEq(prices.length, 1, "Prices length should be 1");

        // Check invariant: shares = assets * priceD18 / 1e18
        // priceD18 = shares * 1e18 / assets = amount * 1e18 / amount = 1e18
        assertEq(prices[0], 1e18, "Price should be equal to the amount");
    }

    /// @dev Test that the price calculation for the base asset is correct.
    /// Case with fees, but with no pending withdrawals.
    function testPriceCalculationForBaseAsset_WithFees() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](1);
        assets[0] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        addRedeemQueue(deployment, vaultProxyAdmin, assetAddress);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assetAddress));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), assetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0.1e6);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 amount = 3 ether;
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        skip(31 days);
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 userShares = deployment.shareManager.sharesOf(user);
        uint256 totalShares = deployment.shareManager.totalShares();
        assertTrue(totalShares > userShares, "Total shares should be greater than user shares (due to fees)");

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
        assertEq(prices.length, 1, "Prices length should be 1");

        // Check invariant: shares = assets * priceD18 / 1e18
        assertApproxEqAbs(
            amount * prices[0] / 1e18, totalShares, 2, "Total shares should be equal to the amount * priceD18 / 1e18"
        );
    }

    /// @dev Test that the price calculation for the base asset is correct.
    /// Case with fees, and with pending withdrawals.
    function testPriceCalculationForBaseAsset_WithFeesAndPendingWithdrawals() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](1);
        assets[0] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, assetAddress)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assetAddress));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), assetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0.1e6);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 amount = 3 ether;
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        // Skip a month to get some fees
        skip(31 days);
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        // Check that the total shares are greater than the user shares (due to fees)
        uint256 userShares = deployment.shareManager.sharesOf(user);
        uint256 totalShares = deployment.shareManager.totalShares();
        assertTrue(totalShares > userShares, "Total shares should be greater than user shares (due to fees)");

        // Request a partial withdrawal
        {
            vm.prank(user);
            redeemQueue.redeem(userShares / 2);
        }

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
        assertEq(prices.length, 1, "Prices length should be 1");

        // Check invariant: shares = assets * priceD18 / 1e18
        assertApproxEqAbs(
            amount * prices[0] / 1e18, totalShares, 2, "Total shares should be equal to the amount * priceD18 / 1e18"
        );

        // Check that the price calculation is correct after the pending withdrawal is processed
        {
            skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
            pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));
            assertApproxEqAbs(amount * prices[0] / 1e18, totalShares, 2);
        }
    }

    /// @dev Test that the price calculation for other asset is correct.
    /// Simple case: no fees, no pending withdrawals, no base asset liquidity and queues.
    function testPriceCalculationForOtherAsset() external {
        MockERC20 baseAsset = new MockERC20();
        address baseAssetAddress = address(baseAsset);

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](2);
        assets[0] = baseAssetAddress;
        assets[1] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        addRedeemQueue(deployment, vaultProxyAdmin, assetAddress);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assetAddress));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), baseAssetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 amount = 3 ether;
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 userShares = deployment.shareManager.sharesOf(user);
        uint256 totalShares = deployment.shareManager.totalShares();
        assertEq(userShares, totalShares, "User shares should be equal to total shares");

        // Check the case when the price of the other asset = price of the base asset
        {
            OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
            assetPrices[0] = OracleHelper.AssetPrice({asset: baseAssetAddress, priceD18: 0});
            assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 1e18});

            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
            assertEq(prices.length, 2, "Prices length should be 2");

            // Check invariant: shares = assets * priceD18 / 1e18
            // priceD18 = shares * 1e18 / assets = amount * 1e18 / amount = 1e18
            assertEq(prices[0], 1e18, "Price of base asset should be equal to the amount");
            assertEq(prices[1], 1e18, "Price of other asset should be equal to the amount");
        }

        // Check the case when the price of the other asset is x2 higher than the price of the base asset
        {
            OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
            assetPrices[0] = OracleHelper.AssetPrice({asset: baseAssetAddress, priceD18: 0});
            assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 2e18});

            // Total assets = amount * 2, because it's expressed in base asset (which is twice cheaper than the other asset)
            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount * 2, assetPrices);
            assertEq(prices.length, 2, "Prices length should be 2");

            // Check invariant: shares = assets * priceD18 / 1e18
            // priceD18 = shares * 1e18 / assets = amount * 1e18 / amount = 1e18
            assertEq(prices[0], 0.5e18, "Price of base asset should be equal to the amount");
            assertEq(prices[1], 1e18, "Price of other asset should be equal to the amount");
        }
    }

    /// @dev Test that the price calculation for other asset is correct.
    /// Simple case: no fees, no pending withdrawals.
    function testPriceCalculationForOtherAsset_WithBaseAssetLiquidity() external {
        MockERC20 baseAsset = new MockERC20();
        address baseAssetAddress = address(baseAsset);

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](2);
        assets[0] = baseAssetAddress;
        assets[1] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), baseAssetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0);

        // Make deposits for each asset from the same user, but base asset is twice cheaper than the other asset.
        for (uint256 i = 0; i < assets.length; i++) {
            addRedeemQueue(deployment, vaultProxyAdmin, assets[i]);
            DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assets[i]));
            IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

            uint224 priceD18 = 1e18;
            if (assets[i] == baseAssetAddress) {
                priceD18 = 0.5e18; // Base asset is twice cheaper than the other asset
            }

            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: priceD18}));

            uint256 amount = 1 ether;
            makeDeposit(user, amount, depositQueue);

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: priceD18}));
        }

        // Assertions
        {
            // Total assets = 1 ether (base asset) + 1 ether (other asset) * 2 (price of the other asset in base asset)
            uint256 totalAssets = 1 ether + (1 ether * 2);

            OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
            assetPrices[0] = OracleHelper.AssetPrice({asset: baseAssetAddress, priceD18: 0});
            assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 2e18});

            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, totalAssets, assetPrices);
            assertEq(prices.length, 2, "Prices length should be 2");
            assertEq(prices[0], 0.5e18, "Price of base asset should be equal to the amount");
            assertEq(prices[1], 1e18, "Price of other asset should be equal to the amount");

            // Check invariant: shares = assets * priceD18 / 1e18
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, totalAssets * prices[0] / 1e18, "Wrong invariant for base asset");
            assertEq(totalShares, (totalAssets / 2) * prices[1] / 1e18, "Wrong invariant for other asset");
        }
    }

    /// @dev Test that the price calculation reverts if the asset is not found.
    function testPriceCalculationShouldRevertIfAssetIsNotFound() external {
        MockERC20 baseAsset = new MockERC20();
        address baseAssetAddress = address(baseAsset);

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](2);
        assets[0] = baseAssetAddress;
        assets[1] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        FeeManager feeManager = deployment.feeManager;

        addRedeemQueue(deployment, vaultProxyAdmin, assetAddress);
        addDepositQueue(deployment, vaultProxyAdmin, assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), baseAssetAddress);

        vm.prank(deployment.vaultAdmin);
        feeManager.setFees(0, 0, 0, 0);

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
        assetPrices[0] = OracleHelper.AssetPrice({asset: baseAssetAddress, priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: vm.addr(1), priceD18: 1e18});

        vm.expectRevert("OracleHelper: asset not found");
        oracleHelper.getPricesD18(deployment.vault, 1 ether, assetPrices);
    }

    /// @dev Test that the price calculation should revert if the base asset is wrong .
    function testPriceCalculationShouldRevertIfBaseAssetIsWrong() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        address[] memory assets = new address[](1);
        assets[0] = assetAddress;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        addRedeemQueue(deployment, vaultProxyAdmin, assetAddress);
        addDepositQueue(deployment, vaultProxyAdmin, assetAddress);

        // Set invalid base asset
        {
            vm.prank(deployment.vaultAdmin);
            deployment.feeManager.setBaseAsset(address(deployment.vault), vm.addr(1));
        }

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        vm.expectRevert("OracleHelper: invalid base asset");
        oracleHelper.getPricesD18(deployment.vault, 1 ether, assetPrices);
    }

    /// @dev Test that the price calculation should revert if the assets are not in order.
    function testPriceCalculationShouldRevertIfAssetsAreNotOrdered() external {
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](3);
        assetPrices[0] = OracleHelper.AssetPrice({asset: 0x0000000000000000000000000000000000000000, priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: 0x0000000000000000000000000000000000000002, priceD18: 1e18});
        assetPrices[2] = OracleHelper.AssetPrice({asset: 0x0000000000000000000000000000000000000001, priceD18: 1e18});

        Vault vault = Vault(payable(vm.addr(1)));

        vm.expectRevert("OracleHelper: invalid asset order");
        oracleHelper.getPricesD18(vault, 0, assetPrices);
    }

    /// @dev Test that the price calculation should revert if the assets are not in order.
    function testPriceCalculationShouldRevertWithMultipleBaseAssets() external {
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
        assetPrices[0] = OracleHelper.AssetPrice({asset: 0x0000000000000000000000000000000000000000, priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: 0x0000000000000000000000000000000000000001, priceD18: 0});

        Vault vault = Vault(payable(vm.addr(1)));

        vm.expectRevert("OracleHelper: multiple base assets");
        oracleHelper.getPricesD18(vault, 0, assetPrices);
    }
}
