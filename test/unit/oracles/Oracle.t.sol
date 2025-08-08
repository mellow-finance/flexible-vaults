// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract OracleTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address[] assetsDefault;

    function setUp() external {
        for (uint256 index = 0; index < 3; index++) {
            assetsDefault.push(address(new MockERC20()));
        }
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;
        assertEq(address(oracle.vault()), address(deployment.vault), "Vault mismatch");
        assertEq(oracle.supportedAssets(), assetsDefault.length, "Assets length mismatch");
        for (uint256 index = 0; index < assetsDefault.length; index++) {
            assertEq(oracle.supportedAssetAt(index), assetsDefault[index], "Asset mismatch");
            assertTrue(oracle.isSupportedAsset(assetsDefault[index]), "Asset not supported");
        }
    }

    function testSetVault() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;

        vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
        oracle.setVault(address(0));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        oracle.setVault(vm.createWallet("randomVault").addr);
    }

    function testRemoveBaseAsset() external {
        address[] memory assets = new address[](5);
        for (uint256 index = 0; index < assets.length; index++) {
            assets[index] = address(new MockERC20());
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        Oracle oracle = deployment.oracle;

        assertEq(oracle.supportedAssets(), assets.length, "Assets length mismatch");
        for (uint256 index = 0; index < assets.length; index++) {
            assertEq(oracle.supportedAssetAt(index), assets[index], "Asset mismatch");
            assertTrue(oracle.isSupportedAsset(assets[index]), "Asset not supported");
        }

        address baseAsset = address(new MockERC20());
        address[] memory tempArray = new address[](1);
        tempArray[0] = baseAsset;
        {
            assertEq(
                deployment.feeManager.baseAsset(address(deployment.vault)), address(0), "Base asset should be unset"
            );
            /// @dev baseAsset is not yet supported
            vm.prank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.UnsupportedAsset.selector, baseAsset));
            oracle.removeSupportedAssets(tempArray);
        }
        {
            vm.prank(deployment.vaultAdmin);
            deployment.feeManager.setBaseAsset(address(deployment.vault), baseAsset);
            assertEq(deployment.feeManager.baseAsset(address(deployment.vault)), baseAsset, "Base asset should be set");

            /// @dev reverts since baseAsset is supported
            vm.prank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.Forbidden.selector));
            oracle.removeSupportedAssets(tempArray);
        }
    }

    function testRemoveAssetWithQueue() external {
        address[] memory assets = new address[](5);
        for (uint256 index = 0; index < assets.length; index++) {
            assets[index] = address(new MockERC20());
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        deployment.feeManager.baseAsset(address(deployment.vault));
        Oracle oracle = deployment.oracle;

        address queue = addDepositQueue(deployment, vaultProxyAdmin, assets[0]);

        /// @dev reverts since queue is using the asset
        vm.startPrank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IOracle.Forbidden.selector));
        oracle.removeSupportedAssets(assets);

        deployment.vault.grantRole(deployment.vault.REMOVE_QUEUE_ROLE(), vaultAdmin);

        deployment.vault.removeQueue(queue);

        /// @dev successfully removes the asset
        oracle.removeSupportedAssets(assets);
        vm.stopPrank();
    }

    function testAddAndRemoveSupportedAsset() external {
        address[] memory assets = new address[](5);
        for (uint256 index = 0; index < assets.length; index++) {
            assets[index] = address(new MockERC20());
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        Oracle oracle = deployment.oracle;

        assertEq(oracle.supportedAssets(), assets.length, "Assets length mismatch");
        for (uint256 index = 0; index < assets.length; index++) {
            assertEq(oracle.supportedAssetAt(index), assets[index], "Asset mismatch");
            assertTrue(oracle.isSupportedAsset(assets[index]), "Asset not supported");
        }

        vm.startPrank(deployment.vaultAdmin);

        vm.expectRevert(abi.encodeWithSelector(IOracle.AlreadySupportedAsset.selector, assets[0]));
        oracle.addSupportedAssets(assets);

        {
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e18;
            reports[0] = IOracle.Report({asset: assets[0], priceD18: price});

            oracle.submitReports(reports);
            oracle.acceptReport(assets[0], price, uint32(block.timestamp));

            IOracle.DetailedReport memory detailedReport = oracle.getReport(assets[0]);
            assertTrue(detailedReport.priceD18 == price, "Report price mismatch");
        }
        oracle.removeSupportedAssets(assets);

        assertEq(oracle.supportedAssets(), 0, "Assets length mismatch");
        for (uint256 index = 0; index < assets.length; index++) {
            assertFalse(oracle.isSupportedAsset(assets[index]), "Asset supported");
        }

        vm.expectRevert(abi.encodeWithSelector(IOracle.UnsupportedAsset.selector, assets[0]));
        oracle.removeSupportedAssets(assets);

        oracle.addSupportedAssets(assets);
        assertEq(oracle.supportedAssets(), assets.length, "Assets length mismatch");
        for (uint256 index = 0; index < assets.length; index++) {
            assertEq(oracle.supportedAssetAt(index), assets[index], "Asset mismatch");
            assertTrue(oracle.isSupportedAsset(assets[index]), "Asset not supported");
        }

        IOracle.DetailedReport memory report = oracle.getReport(assets[0]);
        assertTrue(report.priceD18 == 0, "Report should be removed");
    }

    function testSecurityParams() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;

        IOracle.SecurityParams memory securityParamsDefault = defaultSecurityParams();
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        assertEq(
            securityParams.maxAbsoluteDeviation,
            securityParamsDefault.maxAbsoluteDeviation,
            "Max absolute deviation mismatch"
        );
        assertEq(
            securityParams.suspiciousAbsoluteDeviation,
            securityParamsDefault.suspiciousAbsoluteDeviation,
            "Suspicious absolute deviation mismatch"
        );
        assertEq(
            securityParams.maxRelativeDeviationD18,
            securityParamsDefault.maxRelativeDeviationD18,
            "Max relative deviation mismatch"
        );
        assertEq(
            securityParams.suspiciousRelativeDeviationD18,
            securityParamsDefault.suspiciousRelativeDeviationD18,
            "Suspicious relative deviation mismatch"
        );
        assertEq(securityParams.timeout, securityParamsDefault.timeout, "Timeout mismatch");
        assertEq(securityParams.depositInterval, securityParamsDefault.depositInterval, "interval mismatch");
        assertEq(securityParams.redeemInterval, securityParamsDefault.redeemInterval, "interval mismatch");

        IOracle.SecurityParams memory securityParamsNew = IOracle.SecurityParams({
            maxAbsoluteDeviation: 6e16,
            suspiciousAbsoluteDeviation: 2e16,
            maxRelativeDeviationD18: 4e16,
            suspiciousRelativeDeviationD18: 3e16,
            timeout: 3600,
            depositInterval: 300,
            redeemInterval: 600
        });

        vm.prank(deployment.vaultAdmin);
        oracle.setSecurityParams(securityParamsNew);
        securityParams = oracle.securityParams();

        assertEq(
            securityParams.maxAbsoluteDeviation,
            securityParamsNew.maxAbsoluteDeviation,
            "Max absolute deviation mismatch"
        );
        assertEq(
            securityParams.suspiciousAbsoluteDeviation,
            securityParamsNew.suspiciousAbsoluteDeviation,
            "Suspicious absolute deviation mismatch"
        );
        assertEq(
            securityParams.maxRelativeDeviationD18,
            securityParamsNew.maxRelativeDeviationD18,
            "Max relative deviation mismatch"
        );
        assertEq(
            securityParams.suspiciousRelativeDeviationD18,
            securityParamsNew.suspiciousRelativeDeviationD18,
            "Suspicious relative deviation mismatch"
        );
        assertEq(securityParams.timeout, securityParamsNew.timeout, "Timeout mismatch");
        assertEq(securityParams.depositInterval, securityParamsNew.depositInterval, "interval mismatch");
        assertEq(securityParams.redeemInterval, securityParamsNew.redeemInterval, "interval mismatch");

        IOracle.SecurityParams memory securityParamsNewInvalid = defaultSecurityParams();
        {
            securityParamsNewInvalid.maxAbsoluteDeviation = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.maxAbsoluteDeviation = 1;
        }
        {
            securityParamsNewInvalid.maxRelativeDeviationD18 = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.maxRelativeDeviationD18 = 1;
        }
        {
            securityParamsNewInvalid.depositInterval = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.depositInterval = 1;
        }
        {
            securityParamsNewInvalid.redeemInterval = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.redeemInterval = 1;
        }
        {
            securityParamsNewInvalid.suspiciousAbsoluteDeviation = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.suspiciousAbsoluteDeviation = 1;
        }
        {
            securityParamsNewInvalid.suspiciousRelativeDeviationD18 = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.suspiciousRelativeDeviationD18 = 1;
        }
        {
            securityParamsNewInvalid.timeout = 0;
            vm.startPrank(deployment.vaultAdmin);
            vm.expectRevert(abi.encodeWithSelector(IOracle.ZeroValue.selector));
            oracle.setSecurityParams(securityParamsNewInvalid);
            securityParamsNewInvalid.timeout = 1;
        }

        vm.stopPrank();
    }

    function testValidatePrice() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;
        address asset = assetsDefault[0];
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        bool isValid;
        bool isSuspicious;
        {
            (isValid, isSuspicious) = oracle.validatePrice(1e20, vm.createWallet("random address").addr);
            assertFalse(isValid, "Price should not be valid");
            assertFalse(isSuspicious, "Price should not be suspicious");

            (isValid, isSuspicious) = oracle.validatePrice(1e20, asset);
            assertTrue(isValid, "Price should be valid");
            assertTrue(isSuspicious, "Price should be suspicious");
        }

        {
            deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
            oracle = deployment.oracle;

            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e18;
            reports[0] = IOracle.Report({asset: asset, priceD18: price});

            vm.startPrank(vaultAdmin);
            oracle.submitReports(reports);
            oracle.acceptReport(asset, price, uint32(block.timestamp));
            vm.stopPrank();

            (isValid, isSuspicious) = oracle.validatePrice(price + securityParams.maxAbsoluteDeviation + 1, asset);
            assertFalse(isValid, "Price should not be valid");
            assertFalse(isSuspicious, "Price should not be suspicious");
        }

        {
            deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
            oracle = deployment.oracle;

            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e12;
            reports[0] = IOracle.Report({asset: asset, priceD18: price});

            vm.startPrank(vaultAdmin);
            oracle.submitReports(reports);
            oracle.acceptReport(asset, price, uint32(block.timestamp));
            vm.stopPrank();

            (isValid, isSuspicious) = oracle.validatePrice(price + securityParams.maxAbsoluteDeviation - 1, asset);
            assertFalse(isValid, "Price should not be valid");
            assertFalse(isSuspicious, "Price should not be suspicious");
        }
    }

    function testHandleReport() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;
        address asset = assetsDefault[0];
        IOracle.SecurityParams memory securityParams = oracle.securityParams();
        address invalidAsset = vm.createWallet("random address").addr;

        IOracle.Report[] memory reports = new IOracle.Report[](1);
        uint224 price = 1e18;
        reports[0] = IOracle.Report({asset: invalidAsset, priceD18: price});

        vm.expectRevert(abi.encodeWithSelector(IOracle.Forbidden.selector));
        oracle.submitReports(reports);

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IOracle.UnsupportedAsset.selector, invalidAsset));
        oracle.submitReports(reports);

        reports[0].asset = asset;
        vm.prank(vaultAdmin);
        oracle.submitReports(reports);

        vm.expectRevert(abi.encodeWithSelector(IOracle.UnsupportedAsset.selector, invalidAsset));
        oracle.getReport(invalidAsset);

        IOracle.DetailedReport memory report = oracle.getReport(asset);
        assertEq(report.priceD18, price, "Price mismatch");
        assertEq(report.timestamp, block.timestamp, "Timestamp mismatch");
        assertTrue(report.isSuspicious, "Should be suspicious");

        vm.startPrank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidReport.selector, block.timestamp + 1, block.timestamp));
        oracle.acceptReport(asset, report.priceD18, uint32(block.timestamp + 1));
        vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidReport.selector, asset, block.timestamp));
        oracle.acceptReport(asset, report.priceD18 + 1, uint32(block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidReport.selector, asset, block.timestamp));
        oracle.acceptReport(address(0), report.priceD18, uint32(block.timestamp));

        oracle.acceptReport(asset, report.priceD18, uint32(block.timestamp));

        vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidReport.selector, asset, block.timestamp));
        oracle.acceptReport(asset, report.priceD18, uint32(block.timestamp));

        report = oracle.getReport(asset);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOracle.TooEarly.selector, block.timestamp, report.timestamp + securityParams.timeout
            )
        );
        oracle.submitReports(reports);
        skip(securityParams.timeout + 1);

        {
            reports[0].priceD18 = price + securityParams.maxAbsoluteDeviation + 1;
            vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidPrice.selector, reports[0].priceD18));
            oracle.submitReports(reports);
        }

        {
            reports[0].priceD18 = price + securityParams.maxAbsoluteDeviation - 1;
            oracle.submitReports(reports);
            oracle.validatePrice(reports[0].priceD18, asset);
            oracle.acceptReport(asset, reports[0].priceD18, uint32(block.timestamp));

            report = oracle.getReport(asset);
            assertEq(report.priceD18, reports[0].priceD18, "Price mismatch");
            assertEq(report.timestamp, block.timestamp, "Timestamp mismatch");
            assertFalse(report.isSuspicious, "Should not be suspicious");
        }
        vm.stopPrank();
    }

    function testFuzzNonSuspiciousDeviation(uint8 steps) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;
        address asset = assetsDefault[0];
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        IOracle.DetailedReport memory report;
        IOracle.Report[] memory reports = new IOracle.Report[](1);
        uint224 priceD18 = 1e18;
        reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});

        // Submit a report with initial price
        vm.startPrank(vaultAdmin);
        skip(securityParams.timeout);
        oracle.submitReports(reports);

        report = oracle.getReport(asset);
        assertTrue(report.isSuspicious, "The first report should be suspicious");

        oracle.acceptReport(asset, priceD18, uint32(block.timestamp));
        assertEq(report.priceD18, priceD18, "Report must be accepted");

        skip(securityParams.timeout);
        reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});
        oracle.submitReports(reports);

        report = oracle.getReport(asset);
        assertFalse(report.isSuspicious, "Next report should not be suspicious");
        assertEq(report.priceD18, priceD18, "Report must be accepted");

        vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidReport.selector, asset, block.timestamp));
        oracle.acceptReport(asset, priceD18, uint32(block.timestamp));

        for (uint256 i = 0; i < steps; i++) {
            priceD18 = _applyDeltaX16PriceNonSuspicious(
                priceD18, i % 2 == 0 ? type(int16).max : type(int16).min, securityParams
            );
            skip(securityParams.timeout);
            reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});
            oracle.submitReports(reports);

            report = oracle.getReport(asset);
            assertFalse(report.isSuspicious, "Report should not be suspicious");

            report = oracle.getReport(asset);
            assertEq(report.priceD18, priceD18, "Report must be accepted");
        }
        vm.stopPrank();
    }

    function testFuzzSuspiciousDeviation(int16[] memory deltaPrice) external {
        vm.assume(deltaPrice.length > 0 && deltaPrice.length < 100);
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        Oracle oracle = deployment.oracle;
        address asset = assetsDefault[0];
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        IOracle.DetailedReport memory report;
        IOracle.Report[] memory reports = new IOracle.Report[](1);
        uint224 priceD18 = 1e18;
        reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});

        // Submit a report with initial price
        vm.startPrank(vaultAdmin);
        skip(securityParams.timeout);
        oracle.submitReports(reports);

        report = oracle.getReport(asset);
        assertTrue(report.isSuspicious, "The first report should be suspicious");

        oracle.acceptReport(asset, priceD18, uint32(block.timestamp));
        assertEq(report.priceD18, priceD18, "Report must be accepted");

        for (uint256 i = 0; i < deltaPrice.length; i++) {
            priceD18 = _applyDeltaX16Price(priceD18, deltaPrice[i], securityParams);

            skip(securityParams.timeout);
            reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});
            oracle.submitReports(reports);

            report = oracle.getReport(asset);
            if (report.isSuspicious) {
                oracle.acceptReport(asset, priceD18, uint32(block.timestamp));
            }

            report = oracle.getReport(asset);
            assertEq(report.priceD18, priceD18, "Report must be accepted");
        }
        vm.stopPrank();
    }

    function testFuzzMultipleAssets(int16[] calldata initDeltaPrices, int16[] calldata deltaPrices) external {
        uint256 assetsCount = initDeltaPrices.length;

        vm.assume(assetsCount > 0 && assetsCount < 10);
        vm.assume(deltaPrices.length > 0 && deltaPrices.length < 200);

        address[] memory assets = new address[](assetsCount);
        uint224[] memory assetPrices = new uint224[](assetsCount);

        for (uint256 i = 0; i < assetsCount; i++) {
            assets[i] = address(new MockERC20());
            assetPrices[i] = _applyDeltaX16(1e18, initDeltaPrices[i]);
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        Oracle oracle = deployment.oracle;
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        IOracle.Report[] memory reports = new IOracle.Report[](assetsCount);

        vm.startPrank(vaultAdmin);
        for (uint256 i = 0; i < assetsCount; i++) {
            reports[i] = IOracle.Report({asset: assets[i], priceD18: assetPrices[i]});
        }
        oracle.submitReports(reports);
        for (uint256 i = 0; i < assetsCount; i++) {
            oracle.acceptReport(assets[i], assetPrices[i], uint32(block.timestamp));
        }
        IOracle.DetailedReport memory report;
        for (uint256 i = 0; i < assetsCount; i++) {
            report = oracle.getReport(assets[i]);
            assertEq(report.priceD18, assetPrices[i], "Report price must match submitted price");
        }

        for (uint256 index = 0; index < deltaPrices.length; index++) {
            for (uint256 i = 0; i < assetsCount; i++) {
                assetPrices[i] = _applyDeltaX16Price(assetPrices[i], deltaPrices[index], securityParams);
                reports[i] = IOracle.Report({asset: assets[i], priceD18: assetPrices[i]});
            }

            skip(securityParams.timeout);
            oracle.submitReports(reports);

            for (uint256 i = 0; i < assetsCount; i++) {
                report = oracle.getReport(assets[i]);
                if (report.isSuspicious) {
                    oracle.acceptReport(assets[i], assetPrices[i], uint32(block.timestamp));
                }
                report = oracle.getReport(assets[i]);
                assertEq(report.priceD18, assetPrices[i], "Report price must match submitted price");
            }
        }
        vm.stopPrank();
    }

    function testFuzzMultipleAssetsWithInvalidSubmits(int16[] calldata initDeltaPrices, int16[] calldata deltaPrices)
        external
    {
        uint256 assetsCount = initDeltaPrices.length;

        vm.assume(assetsCount > 0 && assetsCount < 10);
        vm.assume(deltaPrices.length > 0 && deltaPrices.length < 200);

        address[] memory assets = new address[](assetsCount);
        uint224[] memory assetPrices = new uint224[](assetsCount);

        for (uint256 i = 0; i < assetsCount; i++) {
            assets[i] = address(new MockERC20());
            assetPrices[i] = _applyDeltaX16(1e18, initDeltaPrices[i]);
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        Oracle oracle = deployment.oracle;
        IOracle.SecurityParams memory securityParams = oracle.securityParams();

        IOracle.Report[] memory reports = new IOracle.Report[](assetsCount);

        vm.startPrank(vaultAdmin);
        for (uint256 i = 0; i < assetsCount; i++) {
            reports[i] = IOracle.Report({asset: assets[i], priceD18: assetPrices[i]});
        }
        oracle.submitReports(reports);
        for (uint256 i = 0; i < assetsCount; i++) {
            oracle.acceptReport(assets[i], assetPrices[i], uint32(block.timestamp));
        }

        IOracle.DetailedReport memory report;
        for (uint256 i = 0; i < assetsCount; i++) {
            report = oracle.getReport(assets[i]);
            assertEq(report.priceD18, assetPrices[i], "Report price must match submitted price");
        }

        for (uint256 index = 0; index < deltaPrices.length; index++) {
            for (uint256 i = 0; i < assetsCount; i++) {
                report = oracle.getReport(assets[i]);
                assetPrices[i] = _applyDeltaX16(report.priceD18, deltaPrices[index]);
                reports[i] = IOracle.Report({asset: assets[i], priceD18: assetPrices[i]});
            }

            skip(securityParams.timeout);
            try oracle.submitReports(reports) {} catch (bytes memory) {}

            for (uint256 i = 0; i < assetsCount; i++) {
                report = oracle.getReport(assets[i]);
                if (report.isSuspicious) {
                    oracle.acceptReport(assets[i], assetPrices[i], uint32(block.timestamp));
                    report = oracle.getReport(assets[i]);
                    assertEq(report.priceD18, assetPrices[i], "Report price must match submitted price");
                }
            }
        }
        vm.stopPrank();
    }
}
