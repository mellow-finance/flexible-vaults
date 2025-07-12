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

        uint256 signerPk = uint256(keccak256("signer"));
        address signer = vm.addr(signerPk);
        address[] memory signers = new address[](1);
        signers[0] = signer;
        (Consensus consensus,) = createConsensus(deployment, signers);
        SignatureRedeemQueue queue =
            SignatureRedeemQueue(addSignatureRedeemQueue(deployment, vaultProxyAdmin, asset, address(consensus)));

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
        IConsensus.Signature[] memory signatures = new IConsensus.Signature[](1);
        signatures[0] = signOrder(queue, order, signerPk);
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

    function signOrder(SignatureQueue queue, ISignatureQueue.Order memory order, uint256 pk)
        internal
        view
        returns (IConsensus.Signature memory)
    {
        bytes32 hash = queue.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return IConsensus.Signature({signer: vm.addr(pk), signature: abi.encodePacked(r, s, v)});
    }
}
