// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract MockSignatureQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_, address consensusFactory_)
        SignatureQueue(name_, version_, consensusFactory_)
    {}

    function test() external {}
}

contract SignatureQueueTest is FixtureTest {
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
        MockSignatureQueue queue = createQueue(deployment);
        address vault = vm.createWallet("vault").addr;
        address consensus = queue.consensusFactory().create(0, address(this), abi.encode(address(this)));

        vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.NotEntity.selector));
        queue.initialize(abi.encode(asset, vault, abi.encode(address(0), "MockSignatureQueue", "0")));

        queue.initialize(abi.encode(asset, vault, abi.encode(consensus, "MockSignatureQueue", "0")));

        assertTrue(queue.canBeRemoved(), "Queue should be removable");
        assertEq(queue.claimableOf(user), 0, "Claimable should be zero");
        assertEq(queue.claim(user), false, "Claim should be false");
        assertEq(queue.vault(), vault, "Vault address mismatch");
        assertEq(queue.asset(), asset, "Asset address mismatch");
        assertEq(address(queue.consensus()), consensus, "Consensus address mismatch");
        assertEq(queue.nonces(user), 0, "Nonce for user should be zero");
    }

    function testValidateOrder() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        uint256 signerCount = 10;
        uint256 threshold = 5;

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, threshold, signerPks, signatureTypes);

        MockSignatureQueue queue = createQueue(deployment);
        queue.initialize(
            abi.encode(asset, address(deployment.vault), abi.encode(address(consensus), "MockSignatureQueue", "0"))
        );
        ISignatureQueue.Order memory order = ISignatureQueue.Order({
            orderId: 1,
            queue: address(queue),
            asset: asset,
            caller: user,
            recipient: user,
            ordered: 1000,
            requested: 500,
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        IConsensus.Signature[] memory signatures = signOrder(queue, order, signerPks, signers);
        {
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidPrice.selector));
            queue.validateOrder(order, signatures);
        }
        {
            IConsensus.Signature[] memory invalidSignatures = new IConsensus.Signature[](1);
            invalidSignatures[0] =
                IConsensus.Signature({signer: vm.createWallet("invalidSigner").addr, signature: new bytes(0)});
            bytes32 orderHash = queue.hashOrder(order);
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(IConsensus.InvalidSignatures.selector, orderHash, invalidSignatures));
            queue.validateOrder(order, invalidSignatures);
        }
        {
            order.nonce = 1;
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidNonce.selector, user, order.nonce));
            queue.validateOrder(order, signatures);
        }
        {
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidCaller.selector, order.caller));
            queue.validateOrder(order, signatures);
        }
        {
            order.asset = vm.createWallet("invalidAsset").addr;
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidAsset.selector, order.asset));
            queue.validateOrder(order, signatures);
        }
        {
            order.requested = 0;
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.ZeroValue.selector));
            queue.validateOrder(order, signatures);
        }
        {
            order.ordered = 0;
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.ZeroValue.selector));
            queue.validateOrder(order, signatures);
        }
        {
            order.queue = vm.createWallet("invalidQueue").addr;
            signatures = signOrder(queue, order, signerPks, signers);
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidQueue.selector, order.queue));
            queue.validateOrder(order, signatures);
        }
        {
            order.deadline = block.timestamp - 1 days;
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.OrderExpired.selector, order.deadline));
            queue.validateOrder(order, signatures);
        }
    }

    function testValidateOrder_WithPriceRounding() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        uint256 signerCount = 10;
        uint256 threshold = 5;

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, threshold, signerPks, signatureTypes);

        MockSignatureQueue queue = createQueue(deployment);
        queue.initialize(
            abi.encode(asset, address(deployment.vault), abi.encode(address(consensus), "MockSignatureQueue", "0"))
        );

        // Validate that the price is rounded up for deposit order
        {
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(queue),
                asset: asset,
                caller: user,
                recipient: user,
                ordered: 1 ether + 1,
                requested: 1 ether,
                deadline: block.timestamp + 1 days,
                nonce: 0
            });
            IConsensus.Signature[] memory signatures = signOrder(queue, order, signerPks, signers);

            // Make sure we make "deposit" order
            vm.mockCall(
                address(deployment.vault),
                abi.encodeWithSelector(IShareModule.isDepositQueue.selector),
                abi.encode(true)
            );

            // Make sure the oracle is valid and not suspicious
            vm.mockCall(
                address(deployment.oracle),
                abi.encodeWithSelector(IOracle.validatePrice.selector),
                abi.encode(true, false)
            );

            // Validate price is rounded up, it should be 1 ether (not ether - 1 wei)
            vm.expectCall(
                address(deployment.oracle), abi.encodeWithSelector(IOracle.validatePrice.selector, 1 ether, asset)
            );

            vm.prank(user);
            queue.validateOrder(order, signatures);
        }

        // Validate that the price is rounded down for redeem order
        {
            ISignatureQueue.Order memory order = ISignatureQueue.Order({
                orderId: 1,
                queue: address(queue),
                asset: asset,
                caller: user,
                recipient: user,
                ordered: 1 ether ,
                requested: 1 ether + 1,
                deadline: block.timestamp + 1 days,
                nonce: 0
            });
            IConsensus.Signature[] memory signatures = signOrder(queue, order, signerPks, signers);

            // Make sure we make "redeem" order
            vm.mockCall(
                address(deployment.vault),
                abi.encodeWithSelector(IShareModule.isDepositQueue.selector),
                abi.encode(false)
            );

            // Make sure the oracle is valid and not suspicious
            vm.mockCall(
                address(deployment.oracle),
                abi.encodeWithSelector(IOracle.validatePrice.selector),
                abi.encode(true, false)
            );

            // Validate price is rounded down, it should be 1 ether - 1 wei (not 1 ether)
            vm.expectCall(
                address(deployment.oracle), abi.encodeWithSelector(IOracle.validatePrice.selector, 1 ether - 1, asset)
            );

            vm.prank(user);
            queue.validateOrder(order, signatures);
        }
    }

    function createQueue(Deployment memory deployment) internal returns (MockSignatureQueue queue) {
        Factory consensusFactory =
            Factory(address(SignatureQueue(deployment.depositQueueFactory.implementationAt(1)).consensusFactory()));
        MockSignatureQueue queueImplementation =
            new MockSignatureQueue("MockSignatureQueue", 0, address(consensusFactory));
        queue = MockSignatureQueue(
            payable(new TransparentUpgradeableProxy(address(queueImplementation), vaultProxyAdmin, new bytes(0)))
        );
    }
}
