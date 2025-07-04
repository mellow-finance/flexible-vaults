// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockTokenizedShareManager is TokenizedShareManager {
    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    function mintShares(address account, uint256 value) external {
        _mint(account, value);
    }

    function test() external {}
}

contract ShareModuleTest is Test {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;

    Factory factoryImplementation;

    Factory riskManagerFactory;
    Factory subvaultFactory;
    Factory depositQueueFactory;
    Factory redeemQueueFactory;
    Factory verifierFactory;

    Vault vaultImplementation;
    MockTokenizedShareManager shareManagerImplementation;
    FeeManager feeManagerImplementation;
    Oracle oracleImplementation;
    Consensus consensus;
    MockERC20 asset;
    MockERC20 unsupportedAsset;
    MockTokenizedShareManager shareManager;

    function setUp() external {
        Consensus consensusImplementation = new Consensus("Consensus", 1);
        consensus = Consensus(
            address(new TransparentUpgradeableProxy(address(consensusImplementation), vaultProxyAdmin, new bytes(0)))
        );
        consensus.initialize(abi.encode(vaultAdmin));
        vm.prank(vaultAdmin);
        consensus.addSigner(vaultAdmin, 1, IConsensus.SignatureType.EIP712);

        asset = new MockERC20();
        unsupportedAsset = new MockERC20();
    }

    function testCreate() external {
        Vault vault = createVault();
        assertTrue(address(vault.shareManager()) != address(0), "ShareManager should be set");
        assertTrue(address(vault.feeManager()) != address(0), "FeeManager should be set");
        assertTrue(address(vault.oracle()) != address(0), "Oracle should be set");

        vm.expectRevert();
        vault.hasQueue(address(0));

        assertEq(vault.getAssetCount(), 0, "Asset count should be 0");

        vm.expectRevert();
        vault.assetAt(0);

        assertFalse(vault.hasAsset(address(0)));

        vm.expectRevert();
        vault.queueAt(address(0), 0);

        assertEq(vault.getQueueCount(), 0, "Queue count should be 0");
        assertEq(vault.queueLimit(), 0, "QueueLimit count should be 0");

        assertTrue(address(vault.defaultDepositHook()) != address(0), "DefaultDepositHook should be set");
        assertTrue(address(vault.defaultRedeemHook()) != address(0), "DefaultRedeemHook should be set");
    }

    function testCreateDepositQueue() external {
        Vault vault = createVault();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.SET_QUEUE_LIMIT_ROLE()
            )
        );
        vault.setQueueLimit(1);

        vm.prank(vaultAdmin);
        vault.setQueueLimit(1);
        assertEq(vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                vault.CREATE_DEPOSIT_QUEUE_ROLE()
            )
        );
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IShareModule.UnsupportedAsset.selector, unsupportedAsset));
        vault.createDepositQueue(0, vaultProxyAdmin, address(unsupportedAsset), new bytes(0));

        vm.prank(vaultAdmin);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 1, "Queue count should be 1");

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encode(IShareModule.QueueLimitReached.selector));
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
    }

    function testCreateRedeemQueue() external {
        Vault vault = createVault();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.SET_QUEUE_LIMIT_ROLE()
            )
        );
        vault.setQueueLimit(1);

        vm.prank(vaultAdmin);
        vault.setQueueLimit(1);
        assertEq(vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                vault.CREATE_REDEEM_QUEUE_ROLE()
            )
        );
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IShareModule.UnsupportedAsset.selector, unsupportedAsset));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(unsupportedAsset), new bytes(0));

        vm.prank(vaultAdmin);
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 1, "Queue count should be 1");

        vm.prank(vaultAdmin);
        vm.expectRevert(abi.encode(IShareModule.QueueLimitReached.selector));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
    }

    function testPauseQueue() external {
        Vault vault = createVault();

        vm.prank(vaultAdmin);
        vault.setQueueLimit(1);
        assertEq(vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 1, "Queue count should be 1");
        address queue = vault.queueAt(address(asset), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.PAUSE_QUEUE_ROLE()
            )
        );
        vault.pauseQueue(queue);

        vm.startPrank(vaultAdmin);
        vault.grantRole(vault.PAUSE_QUEUE_ROLE(), vaultAdmin);
        vault.grantRole(vault.UNPAUSE_QUEUE_ROLE(), vaultAdmin);

        address invalidQueue = IFactory(depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.pauseQueue(invalidQueue);

        vault.pauseQueue(queue);
        assertTrue(vault.isPausedQueue(queue), "Queue should be paused");

        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.unpauseQueue(invalidQueue);

        vault.unpauseQueue(queue);
        assertFalse(vault.isPausedQueue(queue), "Queue should not be paused");
    }

    function testRemoveQueue() external {
        Vault vault = createVault();

        vm.prank(vaultAdmin);
        vault.setQueueLimit(1);
        assertEq(vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 1, "Queue count should be 1");
        address queue = vault.queueAt(address(asset), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.REMOVE_QUEUE_ROLE()
            )
        );
        vault.removeQueue(queue);

        vm.startPrank(vaultAdmin);
        vault.grantRole(vault.REMOVE_QUEUE_ROLE(), vaultAdmin);

        address invalidQueue = IFactory(depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.removeQueue(invalidQueue);
        vm.stopPrank();

        vm.warp(block.timestamp + 10);
        vm.prank(address(vault));
        IQueue(queue).handleReport(1e6, uint32(block.timestamp - 1));

        vm.startPrank(vaultAdmin);
        vault.removeQueue(queue);

        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.removeQueue(queue);

        assertEq(vault.getQueueCount(), 0, "Queue count should be 0");
    }

    function testGetHook() external {
        Vault vault = createVault();

        vm.startPrank(vaultAdmin);
        vault.setQueueLimit(2);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = vault.queueAt(address(asset), 0);
        address redeemQueue = vault.queueAt(address(asset), 1);

        assertTrue(vault.getHook(depositQueue) == vault.defaultDepositHook(), "mismatch default deposit hook");
        assertTrue(vault.getHook(redeemQueue) == vault.defaultRedeemHook(), "mismatch default redeem hook");

        address newDepositHook = address(new RedirectingDepositHook());
        address newRedeemHook = address(new BasicRedeemHook());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.SET_HOOK_ROLE()
            )
        );
        vault.setDefaultDepositHook(address(this));

        vm.startPrank(vaultAdmin);

        vault.setDefaultDepositHook(newDepositHook);
        assertEq(vault.getHook(depositQueue), newDepositHook, "Default deposit hook should be set");

        vault.setDefaultRedeemHook(newRedeemHook);
        assertEq(vault.getHook(redeemQueue), newRedeemHook, "Default redeem hook should be set");
        vm.stopPrank();
    }

    function testSetCustomHook() external {
        Vault vault = createVault();

        vm.startPrank(vaultAdmin);
        vault.setQueueLimit(2);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = vault.queueAt(address(asset), 0);
        address redeemQueue = vault.queueAt(address(asset), 1);

        assertTrue(vault.getHook(depositQueue) == vault.defaultDepositHook(), "mismatch default deposit hook");
        assertTrue(vault.getHook(redeemQueue) == vault.defaultRedeemHook(), "mismatch default redeem hook");

        address newDepositHook = address(new RedirectingDepositHook());
        address newRedeemHook = address(new BasicRedeemHook());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.SET_HOOK_ROLE()
            )
        );
        vault.setCustomHook(depositQueue, newDepositHook);

        vm.startPrank(vaultAdmin);
        vm.expectRevert(abi.encode(IACLModule.ZeroAddress.selector));
        vault.setCustomHook(address(0), newDepositHook);

        vault.setCustomHook(depositQueue, address(0));

        vault.setCustomHook(depositQueue, newDepositHook);
        assertEq(vault.getHook(depositQueue), newDepositHook, "Custom deposit hook should be set");

        vault.setCustomHook(redeemQueue, newRedeemHook);
        assertEq(vault.getHook(redeemQueue), newRedeemHook, "Custom redeem hook should be set");

        vault.setCustomHook(depositQueue, address(0));
        assertEq(vault.getHook(depositQueue), vault.defaultDepositHook(), "Default deposit hook should be set to zero");

        vm.stopPrank();
    }

    function testHandleReport() external {
        Vault vault = createVault();

        vm.prank(vaultAdmin);
        vault.setQueueLimit(1);
        assertEq(vault.queueLimit(), 1, "QueueLimit count should be 1");

        vm.prank(vaultAdmin);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 1, "Queue count should be 1");
        assertEq(vault.getQueueCount(address(asset)), 1, "Queue count should be 1");
        address queue = vault.queueAt(address(asset), 0);

        vm.warp(block.timestamp + 10);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.handleReport(address(asset), 1e6, uint32(block.timestamp - 1));

        shareManager.mintShares(user, 1 ether);
        vm.prank(address(vault.oracle()));
        vault.handleReport(address(asset), 1e6, uint32(block.timestamp - 1));
    }

    function testGetLiquidAssets() external {
        Vault vault = createVault();

        vm.startPrank(vaultAdmin);
        vault.setQueueLimit(2);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = vault.queueAt(address(asset), 0);
        address redeemQueue = vault.queueAt(address(asset), 1);
        address invalidDepositQueue = IFactory(depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );

        vm.expectRevert();
        vault.getLiquidAssets();

        vm.prank(depositQueue);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.getLiquidAssets();

        vm.prank(redeemQueue);
        vault.getLiquidAssets();
    }

    function testCallHookForbidden() external {
        Vault vault = createVault();

        vm.startPrank(vaultAdmin);
        vault.setQueueLimit(2);
        vault.createDepositQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        vault.createRedeemQueue(0, vaultProxyAdmin, address(asset), new bytes(0));
        assertEq(vault.getQueueCount(), 2, "Queue count should be 2");
        vm.stopPrank();

        address depositQueue = vault.queueAt(address(asset), 0);
        address redeemQueue = vault.queueAt(address(asset), 1);

        vm.expectRevert();
        vault.callHook(0);

        vm.prank(depositQueue);
        vault.callHook(0);

        address invalidDepositQueue = IFactory(depositQueueFactory).create(
            0, vaultProxyAdmin, abi.encode(address(unsupportedAsset), address(this), new bytes(0))
        );

        vm.prank(invalidDepositQueue);
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        vault.callHook(0);
    }

    function createVault() internal returns (Vault vault) {
        factoryImplementation = new Factory("Mellow", 1);

        verifierFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        verifierFactory.initialize(abi.encode(vaultAdmin));

        subvaultFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        subvaultFactory.initialize(abi.encode(vaultAdmin));

        depositQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        depositQueueFactory.initialize(abi.encode(vaultAdmin));

        redeemQueueFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        redeemQueueFactory.initialize(abi.encode(vaultAdmin));

        riskManagerFactory = Factory(
            address(new TransparentUpgradeableProxy(address(factoryImplementation), vaultProxyAdmin, new bytes(0)))
        );
        riskManagerFactory.initialize(abi.encode(vaultAdmin));

        MockTokenizedShareManager shareManagerImplementation = new MockTokenizedShareManager("Mellow", 1);

        shareManager = MockTokenizedShareManager(
            address(new TransparentUpgradeableProxy(address(shareManagerImplementation), vaultProxyAdmin, new bytes(0)))
        );
        vm.startPrank(vaultAdmin);
        {
            address depositQueueImplementation = address(new DepositQueue("Mellow", 1));
            depositQueueFactory.proposeImplementation(depositQueueImplementation);
            depositQueueFactory.acceptProposedImplementation(depositQueueImplementation);
            address signatureDepositQueueImplementation = address(new SignatureDepositQueue("Mellow", 1));
            depositQueueFactory.proposeImplementation(signatureDepositQueueImplementation);
            depositQueueFactory.acceptProposedImplementation(signatureDepositQueueImplementation);

            address redeemQueueImplementation = address(new RedeemQueue("Mellow", 1));
            redeemQueueFactory.proposeImplementation(redeemQueueImplementation);
            redeemQueueFactory.acceptProposedImplementation(redeemQueueImplementation);
            address signatureRedeemQueueImplementation = address(new SignatureRedeemQueue("Mellow", 1));
            redeemQueueFactory.proposeImplementation(signatureRedeemQueueImplementation);
            redeemQueueFactory.acceptProposedImplementation(signatureRedeemQueueImplementation);

            address verifierImplementation = address(new Verifier("Mellow", 1));
            verifierFactory.proposeImplementation(verifierImplementation);
            verifierFactory.acceptProposedImplementation(verifierImplementation);

            address subvaultImplementation = address(new Subvault("Mellow", 1));
            subvaultFactory.proposeImplementation(subvaultImplementation);
            subvaultFactory.acceptProposedImplementation(subvaultImplementation);

            address riskManagerImplementation = address(new RiskManager("Mellow", 1));
            riskManagerFactory.proposeImplementation(riskManagerImplementation);
            riskManagerFactory.acceptProposedImplementation(riskManagerImplementation);
        }

        vm.stopPrank();
        vaultImplementation = new Vault(
            "Mellow",
            1,
            address(depositQueueFactory),
            address(redeemQueueFactory),
            address(subvaultFactory),
            address(verifierFactory)
        );

        vault =
            Vault(payable(new TransparentUpgradeableProxy(address(vaultImplementation), vaultProxyAdmin, new bytes(0))));

        shareManager.initialize(
            abi.encode(address(vault), bytes32(0), string("VaultERC20Name"), string("VaultERC20Symbol"))
        );

        feeManagerImplementation = new FeeManager("Mellow", 1);

        FeeManager feeManager = FeeManager(
            address(new TransparentUpgradeableProxy(address(feeManagerImplementation), vaultProxyAdmin, new bytes(0)))
        );
        feeManager.initialize(
            abi.encode(
                vaultAdmin,
                vaultAdmin, // feeRecipient
                0, // depositFeeD6
                1e4, // redeemFeeD6
                0, // performanceFeeD6
                1e4 // protocolFeeD6
            )
        );

        Oracle oracleImplementation = new Oracle("Mellow", 1);

        Oracle oracle = Oracle(
            address(new TransparentUpgradeableProxy(address(oracleImplementation), vaultProxyAdmin, new bytes(0)))
        );

        {
            address[] memory assets = new address[](1);
            assets[0] = address(asset);
            bytes memory oracleInitParams = abi.encode(
                vault,
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.05 ether,
                    suspiciousAbsoluteDeviation: 0.01 ether,
                    maxRelativeDeviationD18: 0.05 ether,
                    suspiciousRelativeDeviationD18: 0.01 ether,
                    timeout: 12 hours,
                    secureInterval: 1 hours
                }),
                assets
            );
            oracle.initialize(oracleInitParams);
        }

        RiskManager riskManager =
            RiskManager(riskManagerFactory.create(0, vaultProxyAdmin, abi.encode(address(vault), int256(100 ether))));
        address depositHook = address(new RedirectingDepositHook());
        address redeemHook = address(new BasicRedeemHook());
        {
            vm.expectRevert(abi.encode(IACLModule.ZeroAddress.selector));
            vault.initialize(
                abi.encode(
                    vaultAdmin,
                    address(0),
                    address(feeManager),
                    address(riskManager),
                    address(oracle),
                    depositHook,
                    redeemHook,
                    new Vault.RoleHolder[](0)
                ) // redeem module params
            );
            vm.expectRevert(abi.encode(IACLModule.ZeroAddress.selector));
            vault.initialize(
                abi.encode(
                    vaultAdmin,
                    address(shareManager),
                    address(0),
                    address(riskManager),
                    address(oracle),
                    depositHook,
                    redeemHook,
                    new Vault.RoleHolder[](0)
                )
            );
            vm.expectRevert(abi.encode(IACLModule.ZeroAddress.selector));
            vault.initialize(
                abi.encode(
                    vaultAdmin,
                    address(shareManager),
                    address(feeManager),
                    address(riskManager),
                    address(0),
                    depositHook,
                    redeemHook,
                    new Vault.RoleHolder[](0)
                )
            );
        }
        vault.initialize(
            abi.encode(
                vaultAdmin,
                address(shareManager),
                address(feeManager),
                address(riskManager),
                address(oracle),
                depositHook,
                redeemHook,
                new Vault.RoleHolder[](0)
            )
        );

        Verifier verifier = Verifier(verifierFactory.create(0, vaultProxyAdmin, abi.encode(address(vault), bytes32(0))));
        vm.startPrank(vaultAdmin);
        vault.grantFundamentalRole(IACLModule.FundamentalRole.PROXY_OWNER, vaultProxyAdmin);
        grantRoles(vault, oracle, verifier, shareManager, riskManager);
        vm.stopPrank();

        return vault;
    }

    function grantRoles(
        Vault vault,
        Oracle oracle,
        Verifier verifier,
        ShareManager shareManager,
        RiskManager riskManager
    ) internal {
        bytes32[27] memory roles = [
            vault.SET_HOOK_ROLE(),
            vault.CREATE_DEPOSIT_QUEUE_ROLE(),
            vault.CREATE_REDEEM_QUEUE_ROLE(),
            vault.SET_QUEUE_LIMIT_ROLE(),
            vault.CREATE_SUBVAULT_ROLE(),
            vault.DISCONNECT_SUBVAULT_ROLE(),
            vault.RECONNECT_SUBVAULT_ROLE(),
            vault.PULL_LIQUIDITY_ROLE(),
            vault.PUSH_LIQUIDITY_ROLE(),
            oracle.SUBMIT_REPORT_ROLE(),
            oracle.ACCEPT_REPORT_ROLE(),
            oracle.SET_SECURITY_PARAMS_ROLE(),
            oracle.ADD_SUPPORTED_ASSETS_ROLE(),
            oracle.REMOVE_SUPPORTED_ASSETS_ROLE(),
            verifier.SET_MERKLE_ROOT_ROLE(),
            verifier.CALL_ROLE(),
            verifier.ALLOW_CALL_ROLE(),
            verifier.DISALLOW_CALL_ROLE(),
            shareManager.SET_FLAGS_ROLE(),
            shareManager.SET_ACCOUNT_INFO_ROLE(),
            riskManager.SET_VAULT_LIMIT_ROLE(),
            riskManager.SET_SUBVAULT_LIMIT_ROLE(),
            riskManager.MODIFY_PENDING_ASSETS_ROLE(),
            riskManager.MODIFY_VAULT_BALANCE_ROLE(),
            riskManager.MODIFY_SUBVAULT_BALANCE_ROLE(),
            riskManager.ALLOW_SUBVAULT_ASSETS_ROLE(),
            riskManager.DISALLOW_SUBVAULT_ASSETS_ROLE()
        ];
        vm.startPrank(vaultAdmin);
        for (uint256 i = 0; i < roles.length; i++) {
            vault.grantRole(roles[i], vaultAdmin);
        }
    }
}
