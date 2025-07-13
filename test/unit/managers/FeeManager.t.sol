// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract FeeManagerTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;
    address asset;
    address[] assetsDefault;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager manager = deployment.feeManager;
        (
            address owner,
            address feeRecipient,
            uint24 depositFeeD6,
            uint24 redeemFeeD6,
            uint24 performanceFeeD6,
            uint24 protocolFeeD6
        ) = decodeFeeManagerParams(defaultFeeManagerParams(deployment));

        assertEq(manager.owner(), owner, "Owner should match");
        assertEq(manager.feeRecipient(), feeRecipient, "Fee recipient should match");
        assertEq(manager.depositFeeD6(), depositFeeD6, "Deposit fee should match");
        assertEq(manager.redeemFeeD6(), redeemFeeD6, "Redeem fee should match");
        assertEq(manager.performanceFeeD6(), performanceFeeD6, "Performance fee should match");
        assertEq(manager.protocolFeeD6(), protocolFeeD6, "Protocol fee should match");
        assertEq(manager.timestamps(address(deployment.vault)), 0, "Timestamp should be unset");
        assertEq(manager.minPriceD18(address(deployment.vault)), 0, "Max price should be zero");
        assertEq(manager.baseAsset(address(deployment.vault)), address(0), "Asset should not be set");
    }

    function testSetFeesAndAsset() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager manager = deployment.feeManager;
        address feeRecipient = vm.createWallet("feeRecipient").addr;

        vm.startPrank(deployment.vaultAdmin);

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.ZeroAddress.selector));
        manager.setFeeRecipient(address(0));

        manager.setFeeRecipient(feeRecipient);
        assertEq(manager.feeRecipient(), feeRecipient, "Fee recipient should be updated");

        vm.expectRevert(
            abi.encodeWithSelector(IFeeManager.InvalidFees.selector, 1e6 / 4, 1e6 / 4, 1e6 / 4, 1e6 / 4 + 1)
        );
        manager.setFees(1e6 / 4, 1e6 / 4, 1e6 / 4, 1e6 / 4 + 1);

        manager.setFees(1e5, 2e5, 3e5, 4e5);
        assertEq(manager.depositFeeD6(), 1e5, "Deposit fee mismatch");
        assertEq(manager.redeemFeeD6(), 2e5, "Redeem fee mismatch");
        assertEq(manager.performanceFeeD6(), 3e5, "Performance fee mismatch");
        assertEq(manager.protocolFeeD6(), 4e5, "Protocol fee mismatch");

        assertEq(manager.baseAsset(address(deployment.vault)), address(0), "Asset should not be set");

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.ZeroAddress.selector));
        manager.setBaseAsset(address(deployment.vault), address(0));

        manager.setBaseAsset(address(deployment.vault), asset);
        assertEq(manager.baseAsset(address(deployment.vault)), asset, "Asset should be set");

        vm.expectRevert(
            abi.encodeWithSelector(IFeeManager.BaseAssetAlreadySet.selector, address(deployment.vault), asset)
        );
        manager.setBaseAsset(address(deployment.vault), asset);
        vm.stopPrank();
    }

    function testOnlyOwner() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager manager = deployment.feeManager;
        address sender = vm.createWallet("sender").addr;
        address feeRecipient = vm.createWallet("feeRecipient").addr;

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender));
        manager.setFeeRecipient(feeRecipient);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender));
        manager.setFees(1e5, 1e5, 1e5, 1e5);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, sender));
        manager.setBaseAsset(address(deployment.vault), asset);
        vm.stopPrank();
    }

    function testFeeCalculation() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager manager = deployment.feeManager;
        address vault = address(deployment.vault);

        vm.prank(deployment.vaultAdmin);
        manager.setFees(1e5, 2e5, 3e5, 4e5);

        uint256 amount = 1 ether;

        assertEq(manager.calculateDepositFee(amount), 1 ether / 10, "Deposit fee mismatch");
        assertEq(manager.calculateRedeemFee(amount), 2 * 1 ether / 10, "Redeem fee mismatch");

        vm.prank(vault);
        manager.updateState(asset, 1 ether);
        assertEq(manager.timestamps(vault), 0, "Timestamp should be unset");
        assertEq(manager.minPriceD18(vault), 0, "Max price should be zero");

        vm.prank(deployment.vaultAdmin);
        manager.setBaseAsset(vault, asset);

        vm.prank(vault);
        manager.updateState(asset, 1 ether);
        assertEq(manager.timestamps(vault), block.timestamp, "Timestamp should be updated");
        assertEq(manager.minPriceD18(vault), 1 ether, "Max price should be updated");

        // No price/timestamp change, no fee
        {
            uint256 shares = manager.calculateFee(vault, asset, 1 ether, 1 ether);
            assertEq(shares, 0, "Shares should be zero");
        }

        // Check performance fee when price increases
        {
            uint256 shares = manager.calculateFee(vault, asset, 0.9 ether, 1 ether);
            assertEq(shares, 3 * 0.1 ether / 10, "Performance fee mismatch");
        }

        // Check protocol fee when timestamp increases
        {
            vm.warp(block.timestamp + 365 days);
            uint256 shares = manager.calculateFee(vault, asset, 1 ether, 1 ether);
            assertEq(shares, 4 * 1 ether / 10, "Protocol fee mismatch");
        }
    }

    function decodeFeeManagerParams(bytes memory data)
        internal
        pure
        returns (
            address owner,
            address feeRecipient,
            uint24 depositFeeD6,
            uint24 redeemFeeD6,
            uint24 performanceFeeD6,
            uint24 protocolFeeD6
        )
    {
        (owner, feeRecipient, depositFeeD6, redeemFeeD6, performanceFeeD6, protocolFeeD6) =
            abi.decode(data, (address, address, uint24, uint24, uint24, uint24));
    }
}
