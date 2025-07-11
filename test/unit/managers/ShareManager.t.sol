// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract ShareManagerTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;
    address asset;
    address[] assetsDefault;
    bytes32 merkleRoot;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
        merkleRoot = keccak256("merkleRoot");
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        assertEq(manager.sharesOf(user), 0, "Initial shares should be zero");
        assertEq(manager.allocatedShares(), 0, "Initial allocated shares should be zero");
        assertEq(manager.vault(), address(deployment.vault), "Vault mismatch");
        assertEq(manager.whitelistMerkleRoot(), merkleRoot, "MerkleRoot mismatch");
    }

    function testSetVault() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        vm.expectRevert(abi.encodeWithSelector(IShareManager.ZeroValue.selector));
        manager.setVault(address(0));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        manager.setVault(vm.createWallet("randomVault").addr);
    }

    function testMintBurn() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);

        vm.prank(depositQueue);
        vm.expectRevert(abi.encodeWithSelector(IShareManager.ZeroValue.selector));
        manager.mint(user, 0);

        vm.prank(depositQueue);
        vm.expectRevert(abi.encodeWithSelector(IShareManager.ZeroValue.selector));
        manager.burn(user, 0);
    }

    function testFlags() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        IShareManager.Flags memory flagsNew = IShareManager.Flags({
            hasMintPause: false,
            hasBurnPause: false,
            hasTransferPause: false,
            hasWhitelist: false,
            hasTransferWhitelist: false,
            globalLockup: uint32(block.timestamp + 1 days),
            targetedLockup: uint32(2 days)
        });

        vm.expectRevert(abi.encodeWithSelector(IShareManager.Forbidden.selector));
        manager.setFlags(flagsNew);

        vm.prank(deployment.vaultAdmin);
        manager.setFlags(flagsNew);

        IShareManager.Flags memory flags = manager.flags();
        assertEq(flags.hasMintPause, flagsNew.hasMintPause);
        assertEq(flags.hasBurnPause, flagsNew.hasBurnPause);
        assertEq(flags.hasTransferPause, flagsNew.hasTransferPause);
        assertEq(flags.hasWhitelist, flagsNew.hasWhitelist);
        assertEq(flags.hasTransferWhitelist, flagsNew.hasTransferWhitelist);
        assertEq(flags.globalLockup, flagsNew.globalLockup);
        assertEq(flags.targetedLockup, flagsNew.targetedLockup);
    }

    function testAccountInfo() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        vm.prank(deployment.vaultAdmin);
        manager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: uint32(block.timestamp + 1 days)
            })
        );

        IShareManager.AccountInfo memory info = manager.accounts(user);
        assertEq(info.canDeposit, true, "canDeposit should be true");
        assertEq(info.canTransfer, true, "canTransfer should be true");
        assertEq(info.isBlacklisted, false, "isBlacklisted should be false");
        assertEq(info.lockedUntil, uint32(block.timestamp + 1 days), "lockedUntil should be set correctly");
    }

    function testAllocateShares() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        address depositQueue = addDepositQueue(deployment, deployment.vaultProxyAdmin, asset);
        address invalidDepositQueue = IFactory(deployment.depositQueueFactory).create(
            0, deployment.vaultProxyAdmin, abi.encode(address(asset), address(this), new bytes(0))
        );

        vm.prank(invalidDepositQueue);
        vm.expectRevert(abi.encodeWithSelector(IShareManager.Forbidden.selector));
        manager.allocateShares(1 ether);

        vm.expectRevert(abi.encodeWithSelector(IShareManager.InsufficientAllocatedShares.selector, 1 ether, 0));
        manager.mintAllocatedShares(user, 1 ether);

        vm.prank(depositQueue);
        vm.expectRevert(abi.encodeWithSelector(IShareManager.ZeroValue.selector));
        manager.allocateShares(0);

        vm.prank(depositQueue);
        manager.allocateShares(1 ether);
        assertEq(manager.allocatedShares(), 1 ether, "Allocated shares should be updated");

        vm.prank(depositQueue);
        manager.mintAllocatedShares(user, 1 ether);
        assertEq(manager.activeSharesOf(user), 1 ether, "Active shares should be updated");
        assertEq(manager.allocatedShares(), 0, "Allocated shares should be updated");
    }

    function testUpdateChecks() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;
        address from = vm.createWallet("from").addr;
        address to = vm.createWallet("to").addr;
        uint32 timestampLockedFrom = uint32(block.timestamp + 1 days);
        uint32 timestampLockedTo = uint32(block.timestamp + 2 days);
        uint32 globalLockup = uint32(block.timestamp + 6 hours);
        uint32 targetedLockup = uint32(8 hours);

        vm.expectRevert(abi.encodeWithSelector(IShareManager.Forbidden.selector));
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: false,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );

        vm.startPrank(deployment.vaultAdmin);
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: false,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );

        manager.setAccountInfo(
            from,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: timestampLockedFrom
            })
        );
        manager.setAccountInfo(
            to,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: timestampLockedTo
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IShareManager.GlobalLockupNotExpired.selector, block.timestamp, globalLockup)
        );
        manager.updateChecks(from, to);

        vm.warp(timestampLockedFrom - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IShareManager.TargetedLockupNotExpired.selector, block.timestamp, timestampLockedFrom
            )
        );
        manager.updateChecks(from, to);

        vm.warp(timestampLockedFrom + 1);
        manager.updateChecks(from, to);

        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: true,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: false,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );

        vm.expectRevert(abi.encodeWithSelector(IShareManager.BurnPaused.selector));
        manager.updateChecks(from, address(0));

        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: true,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: true,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );
        manager.setAccountInfo(
            to,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: false,
                isBlacklisted: false,
                lockedUntil: timestampLockedTo
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferNotAllowed.selector, from, to));
        manager.updateChecks(from, to);

        manager.setAccountInfo(
            from,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: false,
                isBlacklisted: false,
                lockedUntil: timestampLockedFrom
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferNotAllowed.selector, from, to));
        manager.updateChecks(from, to);

        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: true,
                hasTransferPause: true,
                hasWhitelist: false,
                hasTransferWhitelist: true,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferPaused.selector));
        manager.updateChecks(from, to);

        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: true,
                hasTransferPause: true,
                hasWhitelist: false,
                hasTransferWhitelist: true,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.TransferPaused.selector));
        manager.updateChecks(from, to);
        manager.updateChecks(address(0), to);

        manager.setAccountInfo(
            to,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: false,
                isBlacklisted: true,
                lockedUntil: timestampLockedFrom
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.Blacklisted.selector, to));
        manager.updateChecks(address(0), to);

        manager.setAccountInfo(
            from,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: false,
                isBlacklisted: true,
                lockedUntil: timestampLockedFrom
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.Blacklisted.selector, from));
        manager.updateChecks(from, to);

        manager.setAccountInfo(
            to,
            IShareManager.AccountInfo({
                canDeposit: false,
                canTransfer: false,
                isBlacklisted: false,
                lockedUntil: timestampLockedFrom
            })
        );
        manager.updateChecks(address(0), to);
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: true,
                hasTransferPause: true,
                hasWhitelist: true,
                hasTransferWhitelist: true,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );

        vm.expectRevert(abi.encodeWithSelector(IShareManager.NotWhitelisted.selector, to));
        manager.updateChecks(address(0), to);
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: true,
                hasBurnPause: true,
                hasTransferPause: true,
                hasWhitelist: true,
                hasTransferWhitelist: true,
                globalLockup: globalLockup,
                targetedLockup: targetedLockup
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IShareManager.MintPaused.selector));
        manager.updateChecks(address(0), to);
        vm.stopPrank();
    }

    function testTargetLockup() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        vm.prank(address(deployment.vaultAdmin));
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: false,
                globalLockup: 0,
                targetedLockup: 1 days
            })
        );

        vm.prank(address(deployment.vault));
        manager.mint(user, 1 ether);
    }

    function testIsDepositorWhitelisted() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        vm.startPrank(address(deployment.vaultAdmin));
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: false,
                hasTransferWhitelist: false,
                globalLockup: 0,
                targetedLockup: 1 days
            })
        );

        manager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: false,
                canTransfer: true,
                isBlacklisted: false,
                lockedUntil: uint32(block.timestamp + 1 days)
            })
        );
        assertFalse(manager.isDepositorWhitelisted(user, new bytes32[](0)), "Should not be whitelisted");
        manager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: true,
                hasTransferWhitelist: false,
                globalLockup: 0,
                targetedLockup: 1 days
            })
        );
        assertFalse(manager.isDepositorWhitelisted(user, new bytes32[](0)), "Should not be whitelisted");
        vm.stopPrank();
    }

    function testClaimShares() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        ShareManager manager = deployment.shareManager;

        vm.prank(address(deployment.vault));
        manager.mint(user, 1 ether);

        manager.claimShares(user);
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
        shareManager.initialize(abi.encode(merkleRoot));
        vm.expectRevert(abi.encodeWithSelector(IShareManager.ZeroValue.selector));
        shareManager.setVault(address(0));
        shareManager.setVault(address(deployment.vault));
        vm.stopPrank();
    }
}
