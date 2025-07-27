// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract SignatureDepositQueueTest is FixtureTest {
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
        SignatureDepositQueue queue = createQueue();
        address vault = vm.createWallet("vault").addr;
        address consensus = queue.consensusFactory().create(0, address(this), abi.encode(address(this)));
        queue.initialize(abi.encode(asset, vault, abi.encode(consensus, "MockSignatureQueue", "0")));
    }

    function testDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        uint256 signerCount = 10;
        uint256 threshold = 5;
        IConsensus.Signature[] memory signatures;
        uint256 amount = 1000;
        uint224 priceD18 = 1e18;

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](signerCount);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, threshold, signerPks, signatureTypes);

        SignatureDepositQueue queue =
            SignatureDepositQueue(addSignatureDepositQueue(deployment, vaultProxyAdmin, asset, address(consensus)));

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

        {
            signatures = signOrder(queue, order, signerPks, signers);

            MockERC20(asset).mint(user, amount);

            vm.prank(user);
            MockERC20(asset).approve(address(queue), amount);

            Oracle oracle = deployment.oracle;
            IOracle.Report[] memory reports = new IOracle.Report[](1);

            reports[0] = IOracle.Report({asset: asset, priceD18: priceD18});
            vm.prank(vaultAdmin);
            oracle.submitReports(reports);

            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(ISignatureQueue.InvalidPrice.selector));
            queue.deposit(order, signatures);

            vm.prank(vaultAdmin);
            oracle.acceptReport(asset, priceD18, uint32(block.timestamp));
        }

        vm.prank(user);
        queue.deposit(order, signatures);
        assertEq(MockERC20(asset).balanceOf(address(deployment.vault)), amount);
        assertEq(MockERC20(asset).balanceOf(user), 0);
        assertEq(deployment.shareManager.activeSharesOf(user), amount * priceD18 / 1e18);
    }

    function testDepositETH() external {
        address[] memory assets = new address[](1);
        assets[0] = TransferLibrary.ETH;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](10);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, 5, signerPks, signatureTypes);

        SignatureDepositQueue queue = SignatureDepositQueue(
            addSignatureDepositQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH, address(consensus))
        );

        ISignatureQueue.Order memory order = ISignatureQueue.Order({
            orderId: 1,
            queue: address(queue),
            asset: TransferLibrary.ETH,
            caller: vm.createWallet(string(abi.encodePacked("order.caller"))).addr,
            recipient: vm.createWallet(string(abi.encodePacked("order.recipient"))).addr,
            ordered: 1 ether,
            requested: 1 ether,
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        makeDepositSignature(queue, order, signerPks, signers);
        assertEq(deployment.shareManager.activeSharesOf(order.caller), 0, "Caller should not have shares");
        assertEq(
            deployment.shareManager.activeSharesOf(order.recipient), order.requested, "Recipient should have shares"
        );
    }

    function testFuzzDepositCallerRecipient(address caller, address recipient) external {
        vm.assume(caller != address(0) && recipient != address(0) && caller != recipient);

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](10);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, 5, signerPks, signatureTypes);

        SignatureDepositQueue queue =
            SignatureDepositQueue(addSignatureDepositQueue(deployment, vaultProxyAdmin, asset, address(consensus)));

        ISignatureQueue.Order memory order = ISignatureQueue.Order({
            orderId: 1,
            queue: address(queue),
            asset: asset,
            caller: caller,
            recipient: recipient,
            ordered: 1 ether,
            requested: 1 ether,
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDepositSignature(queue, order, signerPks, signers);
        assertEq(deployment.shareManager.activeSharesOf(caller), 0, "Caller should not have shares");
        assertEq(deployment.shareManager.activeSharesOf(recipient), order.requested, "Recipient should have shares");
    }

    function testFuzzDeposit(int16[10] memory priceDeviation) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        /// @dev Generate signers and their public keys with EIP712 signature type
        IConsensus.SignatureType[] memory signatureTypes = new IConsensus.SignatureType[](10);
        uint256[] memory signerPks;
        address[] memory signers;
        (signerPks, signers, signatureTypes) = generateSortedSigners(signatureTypes);

        (Consensus consensus,) = createConsensus(deployment, 5, signerPks, signatureTypes);

        SignatureDepositQueue queue =
            SignatureDepositQueue(addSignatureDepositQueue(deployment, vaultProxyAdmin, asset, address(consensus)));

        ISignatureQueue.Order memory order = ISignatureQueue.Order({
            orderId: 1,
            queue: address(queue),
            asset: asset,
            caller: user,
            recipient: user,
            ordered: 0,
            requested: 0,
            deadline: block.timestamp + 1 days,
            nonce: 0
        });

        uint224 priceD18 = 1e18;
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        for (uint256 index = 0; index < priceDeviation.length; index++) {
            order.caller = vm.createWallet(string(abi.encodePacked("order.caller", index))).addr;
            order.recipient = order.caller;
            priceD18 = _applyDeltaX16Price(priceD18, priceDeviation[index], securityParams);

            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

            order.nonce = queue.nonces(order.caller);
            order.ordered = 1 ether;
            /// @dev Calculate non suspicious amount
            order.requested = order.ordered
                * _applyDeltaX16PriceNonSuspicious(
                    priceD18, index % 2 == 0 ? type(int16).min : type(int16).max, securityParams
                ) / 1e18;

            order.deadline = block.timestamp + 1 hours;
            makeDepositSignature(queue, order, signerPks, signers);

            assertApproxEqAbs(
                deployment.shareManager.activeSharesOf(order.caller),
                order.requested,
                priceDeviation.length * 2,
                "Shares mismatch"
            );
        }

        assertEq(
            deployment.shareManager.activeSharesOf(deployment.feeManager.feeRecipient()),
            0,
            "Fee recipient should not have shares"
        );
    }

    function createQueue() internal returns (SignatureDepositQueue queue) {
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

        SignatureDepositQueue queueImplementation = new SignatureDepositQueue("Mellow", 1, address(consensusFactory));

        vm.stopPrank();
        queue = SignatureDepositQueue(
            payable(new TransparentUpgradeableProxy(address(queueImplementation), vaultProxyAdmin, new bytes(0)))
        );
    }
}
