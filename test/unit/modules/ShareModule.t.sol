// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract MockTokenizedShareManager is TokenizedShareManager {
    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    function mintShares(address account, uint256 value) external {
        _mint(account, value);
    }

    function test() external {}
}

contract ShareModuleTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;

    MockERC20 asset;
    MockERC20 unsupportedAsset;

    address[] assets;

    function setUp() external {
        asset = new MockERC20();
        unsupportedAsset = new MockERC20();
        assets.push(address(asset));
    }

    function createShareManager(Deployment memory deployment)
        internal
        override
        returns (ShareManager shareManager, ShareManager shareManagerImplementation)
    {
        shareManagerImplementation = new MockTokenizedShareManager("Mellow", 1);
        shareManager = MockTokenizedShareManager(
            address(
                new TransparentUpgradeableProxy(
                    address(shareManagerImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        {
            shareManager.initialize(abi.encode(bytes32(0), string("VaultERC20Name"), string("VaultERC20Symbol")));
            shareManager.setVault(address(deployment.vault));
        }
        vm.stopPrank();
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        assertTrue(address(deployment.vault.shareManager()) != address(0), "ShareManager should be set");
        assertTrue(address(deployment.vault.feeManager()) != address(0), "FeeManager should be set");
        assertTrue(address(deployment.vault.oracle()) != address(0), "Oracle should be set");

        vm.expectRevert();
        deployment.vault.hasQueue(address(0));

        assertEq(deployment.vault.getAssetCount(), 0, "Asset count should be 0");

        vm.expectRevert();
        deployment.vault.assetAt(0);

        assertFalse(deployment.vault.hasAsset(address(0)));

        vm.expectRevert();
        deployment.vault.queueAt(address(0), 0);

        assertEq(deployment.vault.getQueueCount(), 0, "Queue count should be 0");
        assertEq(deployment.vault.queueLimit(), 0, "QueueLimit count should be 0");

        assertTrue(address(deployment.vault.defaultDepositHook()) != address(0), "DefaultDepositHook should be set");
        assertTrue(address(deployment.vault.defaultRedeemHook()) != address(0), "DefaultRedeemHook should be set");
    }

    function testCreateDepositQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.SET_QUEUE_LIMIT_ROLE()
            )
        );
        deployment.vault.setQueueLimit(1);

        vm.prank(vaultAdmin);
        deployment.vault.setQueueLimit(1);
        assertEq(deployment.vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.CREATE_QUEUE_ROLE()
            )
        );
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IShareModule.UnsupportedAsset.selector, unsupportedAsset));
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(unsupportedAsset), new bytes(0));

        vm.prank(vaultAdmin);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 1, "Queue count should be 1");

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encode(IShareModule.QueueLimitReached.selector));
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
    }

    function testCreateRedeemQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.SET_QUEUE_LIMIT_ROLE()
            )
        );
        deployment.vault.setQueueLimit(1);

        vm.prank(vaultAdmin);
        deployment.vault.setQueueLimit(1);
        assertEq(deployment.vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.CREATE_QUEUE_ROLE()
            )
        );
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IShareModule.UnsupportedAsset.selector, unsupportedAsset));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(unsupportedAsset), new bytes(0));

        vm.prank(vaultAdmin);
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 1, "Queue count should be 1");

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encode(IShareModule.QueueLimitReached.selector));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
    }

    function testPauseQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.prank(vaultAdmin);
        deployment.vault.setQueueLimit(1);
        assertEq(deployment.vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 1, "Queue count should be 1");
        address queue = deployment.vault.queueAt(address(asset), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.SET_QUEUE_STATUS_ROLE()
            )
        );
        deployment.vault.setQueueStatus(queue, true);

        vm.startPrank(vaultAdmin);
        deployment.vault.grantRole(deployment.vault.SET_QUEUE_STATUS_ROLE(), vaultAdmin);

        address invalidQueue = IFactory(deployment.depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.setQueueStatus(invalidQueue, true);

        deployment.vault.setQueueStatus(queue, true);
        assertTrue(deployment.vault.isPausedQueue(queue), "Queue should be paused");

        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.setQueueStatus(invalidQueue, false);

        deployment.vault.setQueueStatus(queue, false);
        assertFalse(deployment.vault.isPausedQueue(queue), "Queue should not be paused");
    }

    function testRemoveQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.prank(vaultAdmin);
        deployment.vault.setQueueLimit(1);
        assertEq(deployment.vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 1, "Queue count should be 1");
        address queue = deployment.vault.queueAt(address(asset), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.REMOVE_QUEUE_ROLE()
            )
        );
        deployment.vault.removeQueue(queue);

        vm.startPrank(vaultAdmin);
        deployment.vault.grantRole(deployment.vault.REMOVE_QUEUE_ROLE(), vaultAdmin);

        address invalidQueue = IFactory(deployment.depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.removeQueue(invalidQueue);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);
        vm.prank(address(deployment.vault));
        IQueue(queue).handleReport(1e6, uint32(block.timestamp - 1));

        vm.startPrank(vaultAdmin);
        deployment.vault.removeQueue(queue);

        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.removeQueue(queue);

        assertEq(deployment.vault.getQueueCount(), 0, "Queue count should be 0");
    }

    function testGetHook() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.startPrank(vaultAdmin);
        deployment.vault.setQueueLimit(2);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = deployment.vault.queueAt(address(asset), 0);
        address redeemQueue = deployment.vault.queueAt(address(asset), 1);

        assertTrue(
            deployment.vault.getHook(depositQueue) == deployment.vault.defaultDepositHook(),
            "mismatch default deposit hook"
        );
        assertTrue(
            deployment.vault.getHook(redeemQueue) == deployment.vault.defaultRedeemHook(),
            "mismatch default redeem hook"
        );

        address newDepositHook = address(new RedirectingDepositHook());
        address newRedeemHook = address(new BasicRedeemHook());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.SET_HOOK_ROLE()
            )
        );
        deployment.vault.setDefaultDepositHook(address(this));

        vm.startPrank(vaultAdmin);

        deployment.vault.setDefaultDepositHook(newDepositHook);
        assertEq(deployment.vault.getHook(depositQueue), newDepositHook, "Default deposit hook should be set");

        deployment.vault.setDefaultRedeemHook(newRedeemHook);
        assertEq(deployment.vault.getHook(redeemQueue), newRedeemHook, "Default redeem hook should be set");
        vm.stopPrank();
    }

    function testSetCustomHook() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.startPrank(vaultAdmin);
        deployment.vault.setQueueLimit(2);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = deployment.vault.queueAt(address(asset), 0);
        address redeemQueue = deployment.vault.queueAt(address(asset), 1);

        assertTrue(
            deployment.vault.getHook(depositQueue) == deployment.vault.defaultDepositHook(),
            "mismatch default deposit hook"
        );
        assertTrue(
            deployment.vault.getHook(redeemQueue) == deployment.vault.defaultRedeemHook(),
            "mismatch default redeem hook"
        );

        address newDepositHook = address(new RedirectingDepositHook());
        address newRedeemHook = address(new BasicRedeemHook());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                deployment.vault.SET_HOOK_ROLE()
            )
        );
        deployment.vault.setCustomHook(depositQueue, newDepositHook);

        vm.startPrank(vaultAdmin);
        vm.expectRevert(abi.encode(IACLModule.ZeroAddress.selector));
        deployment.vault.setCustomHook(address(0), newDepositHook);

        deployment.vault.setCustomHook(depositQueue, address(0));

        deployment.vault.setCustomHook(depositQueue, newDepositHook);
        assertEq(deployment.vault.getHook(depositQueue), newDepositHook, "Custom deposit hook should be set");

        deployment.vault.setCustomHook(redeemQueue, newRedeemHook);
        assertEq(deployment.vault.getHook(redeemQueue), newRedeemHook, "Custom redeem hook should be set");

        deployment.vault.setCustomHook(depositQueue, address(0));
        assertEq(
            deployment.vault.getHook(depositQueue),
            deployment.vault.defaultDepositHook(),
            "Default deposit hook should be set to zero"
        );

        vm.stopPrank();
    }

    function testHandleReport() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.prank(vaultAdmin);
        deployment.vault.setQueueLimit(1);
        assertEq(deployment.vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 1, "Queue count should be 1");
        assertEq(deployment.vault.getQueueCount(address(asset)), 1, "Queue count should be 1");

        vm.warp(block.timestamp + 10);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.handleReport(address(asset), 1e6, uint32(block.timestamp - 1), uint32(block.timestamp - 1));

        MockTokenizedShareManager(address(deployment.shareManager)).mintShares(user, 1 ether);
        vm.prank(address(deployment.vault.oracle()));
        deployment.vault.handleReport(address(asset), 1e6, uint32(block.timestamp - 1), uint32(block.timestamp - 1));
    }

    function testGetLiquidAssets() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.startPrank(vaultAdmin);
        deployment.vault.setQueueLimit(2);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = deployment.vault.queueAt(address(asset), 0);
        address redeemQueue = deployment.vault.queueAt(address(asset), 1);

        vm.expectRevert();
        deployment.vault.getLiquidAssets();

        vm.prank(depositQueue);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.getLiquidAssets();

        vm.prank(redeemQueue);
        deployment.vault.getLiquidAssets();
    }

    function testCallHookForbidden() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.startPrank(vaultAdmin);
        deployment.vault.setQueueLimit(2);
        deployment.vault.createQueue(0, true, vaultProxyAdmin, address(asset), new bytes(0));
        deployment.vault.createQueue(0, false, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(deployment.vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = deployment.vault.queueAt(address(asset), 0);

        vm.expectRevert();
        deployment.vault.callHook(0);

        vm.prank(depositQueue);
        deployment.vault.callHook(0);

        address invalidDepositQueue = IFactory(deployment.depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );

        vm.prank(invalidDepositQueue);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment.vault.callHook(0);
    }
}
