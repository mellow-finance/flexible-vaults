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
