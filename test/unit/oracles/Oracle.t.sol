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
        vm.warp(block.timestamp + securityParams.timeout + 1);

        {
            reports[0].priceD18 = price + securityParams.maxAbsoluteDeviation + 1;
            vm.expectRevert(abi.encodeWithSelector(IOracle.InvalidPrice.selector, reports[0].priceD18));
            oracle.submitReports(reports);
        }

        {
            reports[0].priceD18 = price + securityParams.maxAbsoluteDeviation - 1;
            oracle.submitReports(reports);
            oracle.validatePrice(reports[0].priceD18, asset);
        }
        vm.stopPrank();
    }
}
