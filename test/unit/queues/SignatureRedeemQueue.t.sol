// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract SignatureRedeemQueueTest is FixtureTest {
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
        SignatureRedeemQueue queue = createQueue();
        address vault = vm.createWallet("vault").addr;
        address consensus = queue.consensusFactory().create(0, address(this), abi.encode(address(this)));

        queue.initialize(abi.encode(asset, vault, abi.encode(consensus, "MockSignatureQueue", "0")));
    }

    function testRedeem() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        uint256 signerCount = 10;
        uint256 threshold = 5;

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, threshold, signerPks, signatureTypes);

        SignatureRedeemQueue queue = SignatureRedeemQueue(
            payable(addSignatureRedeemQueue(deployment, vaultProxyAdmin, asset, address(consensus)))
        );

        uint256 amount = 1000;
        ISignatureQueue.Order memory order = ISignatureQueue.Order({
            orderId: 1,
            queue: address(queue),
            asset: asset,
            caller: user,
            recipient: user,
            ordered: amount,
            requested: amount,
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        IConsensus.Signature[] memory signatures = signOrder(queue, order, signerPks, signers);

        {
            Oracle oracle = deployment.oracle;
            IOracle.Report[] memory reports = new IOracle.Report[](1);
            uint224 price = 1e18;
            reports[0] = IOracle.Report({asset: asset, priceD18: price});
            vm.startPrank(vaultAdmin);
            oracle.submitReports(reports);
            oracle.acceptReport(asset, price, uint32(block.timestamp));
            vm.stopPrank();
        }

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(SignatureRedeemQueue.InsufficientAssets.selector, order.requested, 0));
        queue.redeem(order, signatures);

        vm.prank(address(queue));
        deployment.shareManager.mint(user, amount);
        MockERC20(asset).mint(address(deployment.vault), amount);

        vm.prank(user);
        queue.redeem(order, signatures);

        assertEq(MockERC20(asset).balanceOf(user), amount, "User should receive assets");
    }

    function testRedeemETH() external {
        address[] memory assets = new address[](1);
        assets[0] = TransferLibrary.ETH;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](10);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, 5, signerPks, signatureTypes);

        SignatureDepositQueue depositQueue = SignatureDepositQueue(
            addSignatureDepositQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH, address(consensus))
        );

        {
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(depositQueue),
                asset: TransferLibrary.ETH,
                caller: vm.createWallet(string(abi.encodePacked("order.caller"))).addr,
                recipient: vm.createWallet(string(abi.encodePacked("order.recipient"))).addr,
                ordered: 1 ether,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: 0
            });

            pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

            makeDepositSignature(depositQueue, order, signerPks, signers);
            assertEq(deployment.shareManager.activeSharesOf(order.caller), 0, "Caller should not have shares");
            assertEq(
                deployment.shareManager.activeSharesOf(order.recipient), order.requested, "Recipient should have shares"
            );

            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));
        }

        SignatureRedeemQueue redeemQueue = SignatureRedeemQueue(
            payable(addSignatureRedeemQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH, address(consensus)))
        );
        {
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(redeemQueue),
                asset: TransferLibrary.ETH,
                caller: vm.createWallet(string(abi.encodePacked("order.caller"))).addr,
                recipient: vm.createWallet(string(abi.encodePacked("order.recipient"))).addr,
                ordered: 1 ether,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: 0
            });
            vm.startPrank(order.caller);
            redeemQueue.redeem(order, signOrder(redeemQueue, order, signerPks, signers));
            vm.stopPrank();
        }
    }

    function testFuzzRedeemCallerRecipient(address[64] calldata recipient) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](10);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, 5, signerPks, signatureTypes);
        address user = vm.createWallet(string(abi.encodePacked("user"))).addr;
        {
            SignatureDepositQueue queue =
                SignatureDepositQueue(addSignatureDepositQueue(deployment, vaultProxyAdmin, asset, address(consensus)));

            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(queue),
                asset: asset,
                caller: user,
                recipient: user,
                ordered: 1 ether,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: 0
            });

            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            makeDepositSignature(queue, order, signerPks, signers);

            assertEq(deployment.shareManager.activeSharesOf(user), order.requested, "Recipient should have shares");
        }

        {
            SignatureRedeemQueue queue = SignatureRedeemQueue(
                payable(addSignatureRedeemQueue(deployment, vaultProxyAdmin, asset, address(consensus)))
            );

            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(queue),
                asset: asset,
                caller: user,
                recipient: address(0),
                ordered: 1 ether / 64,
                requested: 1 ether / 64,
                deadline: 0,
                nonce: 0
            });

            for (uint256 i = 0; i < recipient.length; i++) {
                order.recipient = recipient[i];
                order.nonce = queue.nonces(order.caller);
                order.deadline = block.timestamp + 1 hours;
                if (order.recipient == address(0)) {
                    continue;
                }

                uint256 balanceBefore = MockERC20(asset).balanceOf(order.recipient);

                vm.startPrank(user);
                queue.redeem(order, signOrder(queue, order, signerPks, signers));
                vm.stopPrank();
                assertEq(
                    MockERC20(asset).balanceOf(order.recipient),
                    order.requested + balanceBefore,
                    "Recipient should have assets"
                );
                skip(deployment.oracle.securityParams().timeout);
                pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
            }
        }
    }

    function createQueue() internal returns (SignatureRedeemQueue queue) {
        address deployer = vm.createWallet("deployer").addr;
        vm.startPrank(deployer);
        Factory consensusFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(new Factory("Mellow", 1)),
                    address(0xdead),
                    abi.encodeCall(IFactoryEntity.initialize, (abi.encode(deployer)))
                )
            )
        );
        {
            address implementation = address(new Consensus("Mellow", 1));
            consensusFactory.proposeImplementation(implementation);
            consensusFactory.acceptProposedImplementation(implementation);
        }

        SignatureRedeemQueue queueImplementation =
            new SignatureRedeemQueue("SignatureRedeemQueue", 0, address(consensusFactory));
        queue = SignatureRedeemQueue(
            payable(new TransparentUpgradeableProxy(address(queueImplementation), vaultProxyAdmin, new bytes(0)))
        );
    }
}
