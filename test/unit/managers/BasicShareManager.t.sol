// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract BasicShareManagerTest is FixtureTest {
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
        ShareManager manager = deployment.shareManager;
        assertEq(manager.activeShares(), 0, "Initial shares should be zero");
        assertEq(manager.activeSharesOf(vaultAdmin), 0, "Initial shares should be zero");
    }

    function testMintAndBurn() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);
        address invalidDepositQueue = IFactory(deployment.depositQueueFactory).create(
            0, deployment.vaultProxyAdmin, abi.encode(address(asset), address(this), new bytes(0))
        );

        vm.expectRevert(abi.encodeWithSelector(IShareManager.Forbidden.selector));
        vm.prank(invalidDepositQueue);
        manager.mint(user, 1 ether);

        vm.startPrank(depositQueue);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        manager.mint(address(0), 1 ether);

        manager.mint(user, 1 ether);
        assertEq(manager.activeShares(), 1 ether, "Shares should not be zero");
        assertEq(manager.activeSharesOf(user), 1 ether, "Shares should not be zero");

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        manager.burn(address(0), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 1 ether, 2 ether));
        manager.burn(user, 2 ether);

        manager.burn(user, 1 ether);
        assertEq(manager.activeShares(), 0, "Shares should be zero");
        assertEq(manager.activeSharesOf(user), 0, "Shares should be zero");
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IShareManager.Forbidden.selector));
        vm.prank(invalidDepositQueue);
        manager.burn(user, 1 ether);
    }

    /// @notice Tests that `lockShares` transfers shares to the manager contract
    function testLockShares() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);

        vm.startPrank(depositQueue);
        {
            // Mint shares to the user
            manager.mint(user, 1 ether);
            assertEq(manager.activeSharesOf(user), 1 ether, "User shares should not be zero");
            assertEq(manager.activeSharesOf(address(manager)), 0, "Manager shares should be zero");

            // Lock half of the user's shares to the manager contract
            manager.lock(user, 0.5 ether);
            assertEq(manager.activeSharesOf(user), 0.5 ether, "User shares should not be zero");
            assertEq(manager.activeSharesOf(address(manager)), 0.5 ether, "Manager shares should not be zero");
        }
        vm.stopPrank();
    }

    /// @notice Tests that `lockShares` reverts when the account is the zero address
    function testLockSharesRevertsOnZeroAddress() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);

        vm.startPrank(depositQueue);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        manager.lock(address(0), 1 ether);
        vm.stopPrank();
    }

    /// @notice Tests that `lockShares` reverts when the account has insufficient balance
    function testLockSharesRevertsOnExceedingBalance() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);

        vm.startPrank(depositQueue);
        {
            // Mint shares to the user
            manager.mint(user, 1 ether);
            assertEq(manager.activeSharesOf(user), 1 ether, "User shares should not be zero");
            assertEq(manager.activeSharesOf(address(manager)), 0, "Manager shares should be zero");

            // Trying to lock two times the user's shares
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 1 ether, 2 ether)
            );
            manager.lock(user, 2 ether);
        }
        vm.stopPrank();
    }

    function createShareManager(Deployment memory deployment)
        internal
        override
        returns (ShareManager shareManager, ShareManager shareManagerImplementation)
    {
        shareManagerImplementation = new BasicShareManager("Mellow", 1);
        shareManager = BasicShareManager(
            address(
                new TransparentUpgradeableProxy(
                    address(shareManagerImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        {
            shareManager.initialize(abi.encode(bytes32(0)));
            shareManager.setVault(address(deployment.vault));
        }
        vm.stopPrank();
    }
}
