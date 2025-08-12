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

        (Deployment memory deployment, DepositQueue depositQueue,) = createVaultWithBaseAsset(assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(deployment.oracle.securityParams().timeout, deployment.oracle.securityParams().depositInterval));
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

    /// @dev Tests that the price calculation for a single non-base asset is correct.
    function testPriceCalculationForSingleNonBaseAsset() external {
        MockERC20 asset = new MockERC20();
        address[] memory assets = new address[](1);
        assets[0] = address(asset);

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        addRedeemQueue(deployment, vaultProxyAdmin, assets[0]);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assets[0]));

        // Set the initial price
        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: 1e18}));

        // Make and process a deposit
        makeDeposit(user, 1 ether, depositQueue);
        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: 1e18}));

        // Check that the base asset is not set
        assertNotEq(
            deployment.feeManager.baseAsset(address(deployment.vault)), assets[0], "Base asset should not be set"
        );

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assets[0], priceD18: 0});
        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, 1 ether, assetPrices);

        // Check invariant: shares = assets * priceD18 / 1e18
        uint256 totalShares = deployment.shareManager.totalShares();
        assertEq(totalShares, Math.mulDiv(1 ether, prices[0], 1e18), "Invariant is not met");

        // Check that oracle helper provides the same price for base asset when fees are not set
        {
            // Make sure that there are no fees
            vm.prank(deployment.vaultAdmin);
            deployment.feeManager.setFees(0, 0, 0, 0);

            // Set base asset
            vm.prank(deployment.vaultAdmin);
            deployment.feeManager.setBaseAsset(address(deployment.vault), assets[0]);

            // Make and process another deposit
            makeDeposit(user, 1 ether, depositQueue);
            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: 1e18}));

            // Check that the price calculation is correct
            prices = oracleHelper.getPricesD18(deployment.vault, 2 ether, assetPrices);
            assertEq(prices[0], 1e18, "Price should be equal to the amount");
            assertEq(
                deployment.shareManager.totalShares(), Math.mulDiv(2 ether, prices[0], 1e18), "Invariant is not met"
            );
        }
    }

    /// @dev Test that the price calculation should revert if the price is zero.
    /// Price is zero because there is no minted shares.
    function testPriceCalculationFailsWhenPriceIsZero() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        (Deployment memory deployment,,) = createVaultWithBaseAsset(assetAddress);

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        vm.expectRevert("OracleHelper: invalid price");
        oracleHelper.getPricesD18(deployment.vault, 1e18, assetPrices);
    }

    /// @dev Test that the price calculation should revert if the price is too high >uint224.max.
    function testPriceCalculationFailsWhenPriceIsTooHigh() external {
        address[] memory assets = new address[](2);
        assets[0] = address(new MockERC20());
        assets[1] = address(new MockERC20());
        assets = sort(assets);

        (Deployment memory deployment, DepositQueue[] memory depositQueues,) = createVaultWithMultipleAssets(assets);

        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assets[1], priceD18: 1e18}));

        makeDeposit(user, 1e18, depositQueues[0]);
        makeDeposit(user, 1e18, depositQueues[1]);

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assets[1], priceD18: 1e18}));

        assertGt(deployment.shareManager.totalShares(), 0, "Total shares should be greater than 0");

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assets[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assets[1], priceD18: type(uint176).max});

        vm.expectRevert("OracleHelper: invalid price");
        oracleHelper.getPricesD18(deployment.vault, 1, assetPrices);
    }

    /// @dev Test that the price calculation for the base asset is correct after multiple reports.
    /// Simulates the case when the vault gets yield (liquidity is growing)
    function testPriceCalculationForBaseAsset_IterativeLiquidityGrowth() external {
        uint256 amount = 1e18;

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        (Deployment memory deployment, DepositQueue depositQueue,) = createVaultWithBaseAsset(assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        makeDeposit(user, amount, depositQueue);

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        // Check price is consistently decreasing after multiple reports when the vault gets yield (liquidity is growing)
        uint256 totalShares = deployment.shareManager.totalShares();
        for (uint256 i = 0; i < 5; i++) {
            asset.mint(address(deployment.vault), 0.01 ether);
            amount += 0.01 ether;

            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
            assertEq(prices[0], Math.mulDiv(totalShares, 1 ether, amount), "Wrong price");

            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: uint224(prices[0])}));
        }
    }

    /// @dev Test that the price calculation for the base asset is correct after multiple reports.
    /// Simulates the case when the vault mints protocol fees (shares are growing)
    function testPriceCalculationForBaseAsset_IterativeSharesGrowthViaFees() external {
        uint256 amount = 1e18;

        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);
        (Deployment memory deployment, DepositQueue depositQueue,) = createVaultWithBaseAsset(assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0.1e6); // 10% protocol fees

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        makeDeposit(user, amount, depositQueue);

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        uint256 accumulatedFees = 0;

        // Check price is consistently increasing after multiple reports when the vault mint shares (due to fees)
        for (uint256 i = 0; i < 365; i++) {
            uint256 totalShares = deployment.shareManager.totalShares();
            uint256 recipientShares = deployment.shareManager.activeSharesOf(deployment.feeManager.feeRecipient());
            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
            assertEq(prices[0], Math.mulDiv(totalShares, 1 ether, amount), "Wrong price");

            // Check that the protocol fees are the only source of the price increase
            assertEq(prices[0] - accumulatedFees, 1 ether, "Wrong shares accumulation");

            skip(1 days);
            accumulatedFees += deployment.feeManager.calculateFee(
                address(deployment.vault), assetAddress, prices[0], totalShares - recipientShares
            );
            pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: uint224(prices[0])}));
        }

        // Check that the recipient shares are equal to the accumulated fees
        {
            uint256 recipientShares = deployment.shareManager.activeSharesOf(deployment.feeManager.feeRecipient());
            assertEq(recipientShares, accumulatedFees, "Unexpected recipient shares");
            assertApproxEqAbs(accumulatedFees, 1 ether * 0.1, 10); // ~10% of the total shares
        }
    }

    /// @dev Test that the price calculation for the base asset is correct.
    /// Case with fees, but with no pending withdrawals.
    function testPriceCalculationForBaseAsset_WithFees() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);

        (Deployment memory deployment, DepositQueue depositQueue,) = createVaultWithBaseAsset(assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0.1e6);

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 amount = 3 ether;
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(deployment.oracle.securityParams().timeout, deployment.oracle.securityParams().depositInterval));
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
    /// Case with pending withdrawals.
    function testPriceCalculationForBaseAsset_WithPendingWithdrawals() external {
        MockERC20 asset = new MockERC20();
        address assetAddress = address(asset);
        (Deployment memory deployment, DepositQueue depositQueue, RedeemQueue redeemQueue) =
            createVaultWithBaseAsset(assetAddress);

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0); // Make sure that there are no fees

        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        uint256 amount = 3 ether;
        makeDeposit(user, amount, depositQueue);

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));

        // Check that the total shares are greater than the user shares (due to fees)
        uint256 userShares = deployment.shareManager.sharesOf(user);
        uint256 totalShares = deployment.shareManager.totalShares();
        assertTrue(totalShares == userShares, "Total shares should be equal to user shares");

        // Request a partial withdrawal (half of the initial deposit)
        {
            vm.prank(user);
            redeemQueue.redeem(userShares / 2);
        }

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddress, priceD18: 0});

        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
        assertEq(prices.length, 1, "Prices length should be 1");

        // Check invariant: shares = assets * priceD18 / 1e18
        assertEq(amount * prices[0] / 1e18, totalShares, "Total shares should be equal to the amount * priceD18 / 1e18");

        // Check that the price calculation is correct after the pending withdrawal is processed
        {
            // Check invariant after the price report is pushed
            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assetAddress, priceD18: 1e18}));
            assertEq(amount * prices[0] / 1e18, totalShares);

            // Check invariant after the batch is handled.
            // TVL should be halved because the pending withdrawal is considered to be processed.
            amount /= 2;
            redeemQueue.handleBatches(type(uint256).max);
            totalShares = deployment.shareManager.totalShares();
            prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
            assertEq(amount * prices[0] / 1e18, totalShares);

            // Check invariant after the claim
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(block.timestamp - 1 days);
            redeemQueue.claim(user, timestamps);
            prices = oracleHelper.getPricesD18(deployment.vault, amount, assetPrices);
            assertEq(amount * prices[0] / 1e18, totalShares);
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

    /// @dev Test that that the oracle helper provides valid prices so that the invariant is preserved after deposit and full withdrawal.
    function testPriceCalculationForOtherAsset_WithDynamicLiquidity() external {
        MockERC20 baseAsset = new MockERC20();
        MockERC20 otherAsset = new MockERC20();
        address baseAssetAddress = address(baseAsset);
        address otherAssetAddress = address(otherAsset);

        address[] memory assets = new address[](2);
        assets[0] = baseAssetAddress;
        assets[1] = otherAssetAddress;
        assets = sort(assets);

        (Deployment memory deployment, DepositQueue[] memory depositQueues, RedeemQueue[] memory redeemQueues) =
            createVaultWithMultipleAssets(assets);

        // Make sure that there are no fees
        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        // The price of the other asset is 2x higher than the base asset.
        uint256 amount = 1 ether;
        uint224 baseAssetPrice = 1e18;
        uint224 otherAssetPrice = 2e18;

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](2);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assets[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assets[1], priceD18: otherAssetPrice});

        // Make deposits and push reports
        {
            pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: baseAssetPrice}));
            pushReport(deployment, IOracle.Report({asset: assets[1], priceD18: otherAssetPrice}));

            makeDeposit(user, amount, depositQueues[0]);
            makeDeposit(user, amount, depositQueues[1]);

            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: baseAssetPrice}));
            pushReport(deployment, IOracle.Report({asset: assets[1], priceD18: otherAssetPrice}));

            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 3 ether); // 1 ether (base asset) + 2 ether (other asset in base asset)

            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, 3 ether, assetPrices);
            assertEq(prices.length, 2, "Prices length should be 2");

            // Total assets in base asset = 1 ether (base asset) + 2 ether (other asset in base asset) = 3 ether
            assertEq(totalShares, Math.mulDiv(3 ether, prices[0], 1e18), "Wrong invariant for base asset");

            // Total assets in other asset = 1 ether (other asset) + 0.5 ether (base asset) = 1.5 ether
            assertEq(totalShares, Math.mulDiv(1.5 ether, prices[1], 1e18), "Wrong invariant for other asset");
        }

        // Drain all the liquidity, redeem all the shares
        {
            vm.startPrank(user);
            redeemQueues[0].redeem(1 ether);
            redeemQueues[1].redeem(2 ether);
            vm.stopPrank();

            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, 3 ether, assetPrices);

            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: uint224(prices[0])}));
            pushReport(deployment, IOracle.Report({asset: assets[1], priceD18: uint224(prices[1])}));

            redeemQueues[0].handleBatches(type(uint256).max);
            redeemQueues[1].handleBatches(type(uint256).max);
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = uint32(block.timestamp - 1 days);

            vm.startPrank(user);
            redeemQueues[0].claim(user, timestamps);
            redeemQueues[1].claim(user, timestamps);
            vm.stopPrank();

            assertEq(deployment.shareManager.totalShares(), 0, "All shares should be redeemed");
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

    /// @dev Test that the price calculation respects asset proportions.
    /// Assume there are 3 assets:
    /// - Base asset
    /// - Asset 1 (price = price(Base asset) * 2)
    /// - Asset 2 (price = price(Base asset) * 3)
    function testPriceCalculationHasCorrectAssetProportions() external {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(new MockERC20());
        assetAddresses[1] = address(new MockERC20());
        assetAddresses[2] = address(new MockERC20());

        assetAddresses = sort(assetAddresses);

        (Deployment memory deployment, DepositQueue[] memory depositQueues,) =
            createVaultWithMultipleAssets(assetAddresses);

        pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[2], priceD18: 3e18}));

        // Make deposits for each asset from the same user, but base asset is twice cheaper than the other asset.
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            uint256 amount = 1 ether;
            makeDeposit(user, amount, depositQueues[i]);
        }

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[2], priceD18: 3e18}));

        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](assetAddresses.length);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: 2e18});
        assetPrices[2] = OracleHelper.AssetPrice({asset: assetAddresses[2], priceD18: 3e18});

        // Total assets in base asset = 1 ether (base asset) + 2 ether (asset 1) + 3 ether (asset 2) = 6 ether
        uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, 6 ether, assetPrices);
        assertEq(prices.length, assetAddresses.length, "Prices length should be equal to the number of assets");

        // Invariant: shares = assets * priceD18 / 1e18
        uint256 totalShares = deployment.shareManager.totalShares();
        assertEq(totalShares, 6 ether); // 1 ether (base asset) + 2 ether (asset 1) + 3 ether (asset 2)
        assertEq(totalShares, Math.mulDiv(6 ether, prices[0], 1e18), "Wrong invariant for base asset");
        assertEq(totalShares, Math.mulDiv(3 ether, prices[1], 1e18), "Wrong invariant for asset 1");
        assertEq(totalShares, Math.mulDiv(2 ether, prices[2], 1e18), "Wrong invariant for asset 2");
    }

    /// @dev Tests that the invariant is preserved when the price is reported separately for each token.
    /// Assume there are 3 assets:
    /// - Base asset
    /// - Asset 1 (price = price(Base asset) * 2)
    /// - Asset 2 (price = price(Base asset) * 3)
    /// First step: Report price for Base asset + Asset 1.
    /// Second step: Report price for Base asset + Asset 2.
    function testPriceCalculationIsCorrectAfterSeparateReports() external {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(new MockERC20());
        assetAddresses[1] = address(new MockERC20());
        assetAddresses[2] = address(new MockERC20());

        assetAddresses = sort(assetAddresses);

        (Deployment memory deployment, DepositQueue[] memory depositQueues,) =
            createVaultWithMultipleAssets(assetAddresses);

        // Make sure that there are no fees to get round calculations
        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        // Push initial reports for every asset
        pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[2], priceD18: 3e18}));

        // Define initial price-relations between assets
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](assetAddresses.length);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: 2e18});
        assetPrices[2] = OracleHelper.AssetPrice({asset: assetAddresses[2], priceD18: 3e18});

        uint256 amount = 1 ether;

        uint256[] memory prices;

        // Step 1: Deposit asset1, report price for base asset + asset1
        {
            makeDeposit(user, amount, depositQueues[1]);

            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));

            // Total assets in base asset = amount of asset1 * 2 = 2 ether
            prices = oracleHelper.getPricesD18(deployment.vault, 2 ether, assetPrices);

            // Invariant: shares = assets * priceD18 / 1e18
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 2 ether);

            // TVL(base asset) = amount of asset1 * 2 = 2 ether
            assertEq(totalShares, Math.mulDiv(2 ether, prices[0], 1e18), "Wrong invariant for base asset");

            // TVL(asset 1) = amount of asset1 = 1
            assertEq(totalShares, Math.mulDiv(1 ether, prices[1], 1e18), "Wrong invariant for asset 1");

            // Total assets in asset 3 = TVL(base asset) / 3 = 0.66(6)
            assertApproxEqAbs(
                totalShares, Math.mulDiv(0.666666666666666666 ether, prices[2], 1e18), 2, "Wrong invariant for asset 2"
            );
        }

        // Step 2: Deposit asset 2, report price for base asset + asset 2
        {
            makeDeposit(user, amount, depositQueues[2]);

            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: uint224(prices[0])}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[2], priceD18: uint224(prices[2])}));

            // Total assets in base asset = 2 ether (asset 1) + 3 ether (asset 2) = 5 ether
            prices = oracleHelper.getPricesD18(deployment.vault, 5 ether, assetPrices);

            // Invariant: shares = assets * priceD18 / 1e18
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 5 ether);

            // TVL(base asset) = amount of asset1 * 2 + amount of asset2 * 3 = 2 ether + 3 ether = 5 ether
            assertEq(totalShares, Math.mulDiv(5 ether, prices[0], 1e18), "Wrong invariant for base asset");

            // TVL(asset 1) = amount of asset1 + amount of asset2 * 1.5 = 1 ether + 1.5 ether = 2.5 ether
            assertEq(totalShares, Math.mulDiv(2.5 ether, prices[1], 1e18), "Wrong invariant for asset 1");

            // Total assets in asset 3 = TVL(base asset) / 3 = 1.66(6)
            assertApproxEqAbs(
                totalShares, Math.mulDiv(1.666666666666666666 ether, prices[2], 1e18), 2, "Wrong invariant for asset 2"
            );
        }
    }

    /// @dev Tests that the price calculation is correct when the price relation between assets is changing.
    function testPriceCalculationWithDynamicPriceRelation() external {
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(new MockERC20());
        assetAddresses[1] = address(new MockERC20());
        assetAddresses = sort(assetAddresses);

        (Deployment memory deployment, DepositQueue[] memory depositQueues, RedeemQueue[] memory redeemQueues) =
            createVaultWithMultipleAssets(assetAddresses);

        // Make sure that there are no fees to get accurate calculations
        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        // Push initial reports for every asset
        pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));

        // Define initial price-relations between assets, base asset is 2 times cheaper than the other asset.
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](assetAddresses.length);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: 2e18});

        // Make same amount of deposits for each asset from the same user
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            uint256 amount = 1 ether;
            makeDeposit(user, amount, depositQueues[i]);
        }

        skip(1 days);
        pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
        pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 2e18}));

        uint256[] memory prices;

        // Check that the price calculation is correct for the initial price-relation between assets
        {
            // Total assets in base asset = 1 ether (base asset) + 2 ether (other asset) = 3 ether
            prices = oracleHelper.getPricesD18(deployment.vault, 3 ether, assetPrices);
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 3 ether);

            // TVL(base asset) = 1 ether (base asset) + 2 ether (other asset) = 3 ether
            assertEq(totalShares, Math.mulDiv(3 ether, prices[0], 1e18), "Wrong invariant for base asset");

            // TVL(asset 1) = 1 ether (other asset)
            assertEq(totalShares, Math.mulDiv(1.5 ether, prices[1], 1e18), "Wrong invariant for other asset");
        }

        // Assume that price of other asset changed, increased by 1%
        {
            assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});

            uint224 newOtherAssetPrice = uint224(Math.mulDiv(2e18, 101, 100));
            assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: newOtherAssetPrice});

            // Total assets in base asset = shares * priceD18 / 1e18 = 3 ether
            uint256 baseAssetTVL = 3 ether;
            uint256[] memory newPrices = oracleHelper.getPricesD18(deployment.vault, baseAssetTVL, assetPrices);
            assertEq(newPrices[0], prices[0], "Base asset price should be the same as the initial price");
            assertGt(newPrices[1], prices[1], "Other asset price should be greater than the initial price");

            // Report new prices
            skip(1 days);
            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: uint224(newPrices[0])}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: uint224(newPrices[1])}));

            // Check that invariant is preserved
            prices = oracleHelper.getPricesD18(deployment.vault, baseAssetTVL, assetPrices);
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 3 ether);
            assertApproxEqAbs(
                totalShares, Math.mulDiv(baseAssetTVL, prices[0], 1e18), 1, "Wrong invariant for base asset"
            );
            uint256 otherAssetTVL = Math.mulDiv(baseAssetTVL, 100, 202);
            assertApproxEqAbs(
                totalShares, Math.mulDiv(otherAssetTVL, prices[1], 1e18), 3, "Wrong invariant for other asset"
            );

            // Check proportion after withdrawal
            {
                uint256 timestamp = block.timestamp;
                vm.startPrank(user);
                redeemQueues[0].redeem(1 ether);
                redeemQueues[1].redeem(2 ether);
                vm.stopPrank();

                skip(1 days);
                pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: uint224(prices[0])}));
                pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: uint224(prices[1])}));

                redeemQueues[0].handleBatches(type(uint256).max);
                redeemQueues[1].handleBatches(type(uint256).max);
                uint32[] memory timestamps = new uint32[](1);
                timestamps[0] = uint32(timestamp);

                vm.startPrank(user);
                redeemQueues[0].claim(user, timestamps);
                redeemQueues[1].claim(user, timestamps);
                vm.stopPrank();

                uint256 balanceBaseAsset = IERC20(assetAddresses[0]).balanceOf(user);
                uint256 balanceOtherAsset = IERC20(assetAddresses[1]).balanceOf(user);
                assertEq(balanceBaseAsset, 1 ether, "Base asset balance should be the same as initial deposit");
                assertLt(balanceOtherAsset, 1 ether, "Other asset balance should be less than initial deposit");

                assertEq(deployment.shareManager.totalShares(), 0, "All shares should be redeemed");
            }
        }
    }

    /// @dev Test that the price calculation is correct when the assets have different decimals.
    /// Assume base asset has 18 decimals and other asset has 6 decimals.
    /// Other asset is two times cheaper than the base asset.
    function testPriceCalculationWithDifferentDecimals() external {
        MockERC20 baseAsset = new MockERC20();
        baseAsset.setDecimals(18);
        MockERC20 otherAsset = new MockERC20();
        otherAsset.setDecimals(6);

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(baseAsset);
        assetAddresses[1] = address(otherAsset);
        assetAddresses = sort(assetAddresses);

        (Deployment memory deployment, DepositQueue[] memory depositQueues,) =
            createVaultWithMultipleAssets(assetAddresses);

        // Make sure that there are no fees
        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        // Make and handle deposits to mint some shares
        {
            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 1e30 / 2}));

            makeDeposit(user, 1 ether, depositQueues[0]);
            makeDeposit(user, 1e6, depositQueues[1]);

            skip(1 days);

            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: 1e18}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: 1e30 / 2}));
        }

        // Define initial prices:
        // - Base asset price = N
        // - Other asset price = N / 2
        OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](assetAddresses.length);
        assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});
        assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: 1e30 / 2});

        // Make assertions in the loop to check that the price is stable after multiple oracle reports.
        // Price should be stable because there was no change in shares, assets or price-relation between assets.
        for (uint256 i = 0; i < 8; i++) {
            // Total assets in base asset = 1 ether (base asset) + 0.5 ether (other asset) = 1.5 ether
            uint256[] memory prices = oracleHelper.getPricesD18(deployment.vault, 1.5 ether, assetPrices);
            assertEq(prices.length, assetAddresses.length, "Prices length should be equal to the number of assets");

            // Invariant: shares = assets * priceD18 / 1e18
            uint256 totalShares = deployment.shareManager.totalShares();
            assertEq(totalShares, 1.5 ether); // 1 ether (base asset) + 0.5 ether (other asset)
            assertEq(totalShares, Math.mulDiv(1.5 ether, prices[0], 1e18), "Wrong invariant for base asset");
            assertEq(totalShares, Math.mulDiv(3 ether, prices[1], 1e30), "Wrong invariant for other asset");

            // Since there was no change in shares or assets, the price should be the same as the initial price
            uint256 initBaseAssetPrice = deployment.oracle.getReport(assetAddresses[0]).priceD18;
            uint256 initOtherAssetPrice = deployment.oracle.getReport(assetAddresses[1]).priceD18;
            assertEq(initBaseAssetPrice, prices[0], "Base asset price should be equal to the initial price");
            assertEq(initOtherAssetPrice, prices[1], "Other asset price should be equal to the initial price");

            skip(1 days);

            pushReport(deployment, IOracle.Report({asset: assetAddresses[0], priceD18: uint224(prices[0])}));
            pushReport(deployment, IOracle.Report({asset: assetAddresses[1], priceD18: uint224(prices[1])}));

            // Re-use the helper's asset prices for the next iteration
            assetPrices[0] = OracleHelper.AssetPrice({asset: assetAddresses[0], priceD18: 0});
            assetPrices[1] = OracleHelper.AssetPrice({asset: assetAddresses[1], priceD18: prices[1]});
        }
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

    /// @dev Create a vault with multiple assets.
    function createVaultWithMultipleAssets(address[] memory assetAddresses)
        private
        returns (Deployment memory deployment, DepositQueue[] memory depositQueue, RedeemQueue[] memory redeemQueue)
    {
        deployment = createVault(vaultAdmin, vaultProxyAdmin, assetAddresses);
        depositQueue = new DepositQueue[](assetAddresses.length);
        redeemQueue = new RedeemQueue[](assetAddresses.length);
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            redeemQueue[i] = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, assetAddresses[i])));
            depositQueue[i] = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assetAddresses[i]));
        }
        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setBaseAsset(address(deployment.vault), assetAddresses[0]);
    }

    /// @dev Create a vault with a single base asset.
    function createVaultWithBaseAsset(address assetAddress)
        private
        returns (Deployment memory deployment, DepositQueue depositQueue, RedeemQueue redeemQueue)
    {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = assetAddress;
        (Deployment memory _deployment, DepositQueue[] memory depositQueues, RedeemQueue[] memory redeemQueues) =
            createVaultWithMultipleAssets(assetAddresses);
        return (_deployment, depositQueues[0], redeemQueues[0]);
    }

    /// @dev Sort an array of addresses in ascending order.
    function sort(address[] memory a) private pure returns (address[] memory) {
        for (uint256 i = 1; i < a.length; i++) {
            address key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    j--;
                }
            }
            a[j] = key;
        }
        return a;
    }
}
