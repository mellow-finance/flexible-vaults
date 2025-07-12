// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract RiskManagerTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;
    address asset;
    address[] assetsDefault;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
        assetsDefault.push(address(new MockERC20()));
        assetsDefault.push(address(new MockERC20()));
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;

        assertEq(manager.vault(), address(deployment.vault), "Vault should match");
        {
            assertEq(manager.vaultState().balance, 0, "Vault balance mismatch");
            assertEq(manager.vaultState().limit, 100 ether, "Vault limit mismatch");

            vm.prank(vaultAdmin);
            manager.setVaultLimit(200 ether);
            assertEq(manager.vaultState().limit, 200 ether, "Subvault limit mismatch");
        }
        assertEq(manager.pendingBalance(), 0, "Pending assets mismatch");
        assertEq(manager.pendingAssets(asset), 0, "Pending assets mismatch");
        assertEq(manager.pendingShares(asset), 0, "Pending shares mismatch");

        vm.prank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));
        {
            assertEq(manager.subvaultState(subvault).balance, 0, "Subvault balance mismatch");
            assertEq(manager.subvaultState(subvault).limit, 0, "Subvault limit mismatch");

            vm.prank(vaultAdmin);
            manager.setSubvaultLimit(subvault, 10 ether);
            assertEq(manager.subvaultState(subvault).limit, 10 ether, "Subvault limit mismatch");
        }
    }

    function testSetVault() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;

        vm.expectRevert(abi.encodeWithSelector(IRiskManager.ZeroValue.selector));
        manager.setVault(address(0));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        manager.setVault(vm.createWallet("randomVault").addr);
    }

    function testAllowAssets() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;

        vm.prank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));
        assertEq(manager.allowedAssets(subvault), 0, "Asset should be allowed");

        vm.expectRevert(abi.encodeWithSelector(IRiskManager.Forbidden.selector));
        manager.allowSubvaultAssets(subvault, assetsDefault);

        address invalidSubvault = vm.createWallet("invalidSubvault").addr;

        vm.expectRevert(abi.encodeWithSelector(IRiskManager.NotSubvault.selector, invalidSubvault));
        manager.requireValidSubvault(address(deployment.vault), invalidSubvault);
        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.NotSubvault.selector, invalidSubvault));
        manager.allowSubvaultAssets(invalidSubvault, assetsDefault);

        vm.prank(vaultAdmin);
        manager.allowSubvaultAssets(subvault, assetsDefault);

        assertEq(manager.allowedAssets(subvault), assetsDefault.length, "Asset should be allowed");
        for (uint256 index = 0; index < assetsDefault.length; index++) {
            assertEq(manager.allowedAssetAt(subvault, index), assetsDefault[index], "Asset should match");
            assertEq(manager.isAllowedAsset(subvault, assetsDefault[index]), true, "Asset should be allowed");
        }

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.AlreadyAllowedAsset.selector, assetsDefault[0]));
        manager.allowSubvaultAssets(subvault, assetsDefault);
    }

    function testDisallowAssets() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;

        vm.prank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));
        assertEq(manager.allowedAssets(subvault), 0, "Asset should be allowed");

        vm.expectRevert(abi.encodeWithSelector(IRiskManager.Forbidden.selector));
        manager.disallowSubvaultAssets(subvault, assetsDefault);

        address invalidSubvault = vm.createWallet("invalidSubvault").addr;

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.NotSubvault.selector, invalidSubvault));
        manager.disallowSubvaultAssets(invalidSubvault, assetsDefault);

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.NotAllowedAsset.selector, assetsDefault[0]));
        manager.disallowSubvaultAssets(subvault, assetsDefault);

        vm.prank(vaultAdmin);
        manager.allowSubvaultAssets(subvault, assetsDefault);

        vm.prank(vaultAdmin);
        manager.disallowSubvaultAssets(subvault, assetsDefault);
        assertEq(manager.allowedAssets(subvault), 0, "Asset should be allowed");
    }

    function testModify() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;
        Oracle oracle = deployment.oracle;

        address queue = addDepositQueue(deployment, vaultProxyAdmin, asset);

        vm.prank(queue);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.InvalidReport.selector));
        manager.modifyVaultBalance(asset, 1 ether);

        {
            vm.startPrank(vaultAdmin);
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e18;
            reports[0] = IOracle.Report({asset: asset, priceD18: price});

            oracle.submitReports(reports);
            oracle.acceptReport(asset, price, uint32(block.timestamp));
            vm.stopPrank();
        }
        {
            vm.startPrank(queue);
            manager.modifyVaultBalance(asset, 1 ether);
            assertEq(manager.vaultState().balance, 1 ether, "Vault balance mismatch");

            vm.expectRevert(
                abi.encodeWithSelector(
                    IRiskManager.LimitExceeded.selector,
                    1000 ether + uint256(manager.pendingAssets(asset)) + uint256(manager.vaultState().balance),
                    manager.vaultState().limit
                )
            );
            manager.modifyVaultBalance(asset, 1000 ether);
            assertEq(manager.vaultState().balance, 1 ether, "Vault balance mismatch");
            vm.stopPrank();
        }
        {
            vm.startPrank(queue);
            manager.modifyPendingAssets(asset, 1 ether);

            vm.expectRevert(
                abi.encodeWithSelector(
                    IRiskManager.LimitExceeded.selector,
                    1000 ether + uint256(manager.pendingAssets(asset)) + uint256(manager.vaultState().balance),
                    manager.vaultState().limit
                )
            );
            manager.modifyPendingAssets(asset, 1000 ether);
            vm.stopPrank();
        }
        {
            vm.prank(deployment.vaultAdmin);
            address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));

            vm.expectRevert(abi.encodeWithSelector(IRiskManager.Forbidden.selector));
            manager.modifySubvaultBalance(subvault, asset, 1 ether);

            vm.prank(address(deployment.vault));
            vm.expectRevert(abi.encodeWithSelector(IRiskManager.NotAllowedAsset.selector, asset));
            manager.modifySubvaultBalance(subvault, asset, 1 ether);

            vm.prank(vaultAdmin);
            manager.allowSubvaultAssets(subvault, assetsDefault);

            vm.prank(address(deployment.vault));
            vm.expectRevert(abi.encodeWithSelector(IRiskManager.LimitExceeded.selector, 1 ether, 0));
            manager.modifySubvaultBalance(subvault, asset, 1 ether);

            vm.prank(vaultAdmin);
            manager.setSubvaultLimit(subvault, 2 ether);

            vm.prank(address(deployment.vault));
            manager.modifySubvaultBalance(subvault, asset, 1 ether);
        }
    }

    function testMaxDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;
        Oracle oracle = deployment.oracle;

        address invalidSubvault = vm.createWallet("invalidSubvault").addr;

        assertEq(manager.maxDeposit(invalidSubvault, asset), 0, "Invalid subvault should have 0 max deposit");

        vm.prank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));

        assertEq(manager.maxDeposit(subvault, asset), 0, "Subvault should have 0 max deposit");

        vm.prank(vaultAdmin);
        manager.setSubvaultLimit(subvault, 1 ether);

        vm.prank(vaultAdmin);
        manager.allowSubvaultAssets(subvault, assetsDefault);

        assertEq(manager.maxDeposit(subvault, asset), 0, "Subvault should have 0 max deposit");

        {
            vm.startPrank(vaultAdmin);
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e18;
            reports[0] = IOracle.Report({asset: asset, priceD18: price});

            oracle.submitReports(reports);
            assertEq(manager.maxDeposit(subvault, asset), 0, "Subvault should have 0 max deposit");
            oracle.acceptReport(asset, price, uint32(block.timestamp));
            vm.stopPrank();
        }

        vm.prank(address(deployment.vault));
        manager.modifySubvaultBalance(subvault, asset, 0.5 ether);

        assertEq(manager.maxDeposit(subvault, asset), 0.5 ether, "Subvault should have 0.5 ether max deposit");

        vm.prank(address(deployment.vault));
        manager.modifySubvaultBalance(subvault, asset, 0.5 ether);
        assertEq(manager.maxDeposit(subvault, asset), 0, "Subvault should have 0 max deposit");
    }

    function testConvertToShares() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RiskManager manager = deployment.riskManager;
        Oracle oracle = deployment.oracle;

        vm.expectRevert(abi.encodeWithSelector(IRiskManager.InvalidReport.selector));
        manager.convertToShares(asset, 1 ether);

        vm.startPrank(vaultAdmin);
        IOracle.Report[] memory reports = new IOracle.Report[](1);
        uint224 price = 1e17;
        reports[0] = IOracle.Report({asset: asset, priceD18: price});

        oracle.submitReports(reports);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.InvalidReport.selector));
        manager.convertToShares(asset, 1 ether);

        oracle.acceptReport(asset, price, uint32(block.timestamp));
        vm.stopPrank();

        assertEq(manager.convertToShares(asset, 1 ether), 0.1 ether, "Subvault should have 0.1 shares");
    }
}
