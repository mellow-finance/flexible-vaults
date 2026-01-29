// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";
import "./DepositQueue.t.sol";

contract RedeemQueueTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;

    address asset;
    address[] assetsDefault;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue queue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();
        (uint256 batchIterator, uint256 length, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator must be 0");
        assertEq(length, 0, "Length must be zero");
        assertEq(totalDemandAssets, 0, "Total demand assets must be zero");
        assertEq(totalPendingShares, 0, "Total pending assets must be zero");

        skip(securityParams.redeemInterval);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        assertTrue(queue.canBeRemoved(), "Can be removed");

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 0, amount));
        queue.redeem(amount);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 10);
        assertEq(requests.length, 0, "User should have no requests");

        (uint256 assets, uint256 shares) = queue.batchAt(0);
        assertEq(assets, 0, "Assets must be zero");
        assertEq(shares, 0, "Shares must be zero");

        {
            skip(securityParams.timeout);
            uint32[] memory timestamps = new uint32[](3);
            timestamps[0] = uint32(block.timestamp - securityParams.redeemInterval);
            timestamps[1] = uint32(block.timestamp);
            timestamps[2] = uint32(block.timestamp + securityParams.redeemInterval);

            vm.prank(user);
            assets = queue.claim(user, timestamps);
            assertEq(assets, 0, "User should not have claimed any assets");

            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            vm.prank(user);
            assets = queue.claim(user, timestamps);
            assertEq(assets, 0, "User should not have claimed any assets");

            assertEq(queue.handleBatches(10), 0, "Should not handle any batches");
        }
    }

    function testSingleDepositRedeem() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        (, uint256 shares) = depositQueue.requestOf(user);
        uint32 redeemTimestamp = uint32(block.timestamp);

        // during redeeming, all unclaimed shares are claimed
        vm.prank(user);
        redeemQueue.redeem(shares / 2);

        assertEq(deployment.shareManager.sharesOf(user), shares / 2, "User should have half of the shares after redeem");
        assertEq(MockERC20(asset).balanceOf(user), 0, "User should have no assets before claim");

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = redeemTimestamp;

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(MockERC20(asset).balanceOf(user), 0, "User should have no assets before handleBatches");

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        redeemQueue.handleBatches(1);

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(deployment.shareManager.sharesOf(user), shares / 2, "User should have half of the shares after redeem");
        assertEq(
            MockERC20(asset).balanceOf(user), amount / 2, "User should have half of the assets after handleBatches"
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, shares / 2, shares)
        );
        redeemQueue.redeem(shares);

        vm.prank(user);
        redeemQueue.redeem(shares / 2);
        timestamps[0] = uint32(block.timestamp);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        redeemQueue.handleBatches(1);

        vm.prank(user);
        redeemQueue.claim(user, timestamps);

        assertEq(deployment.shareManager.sharesOf(user), 0, "User should have no shares after redeem");
        assertEq(MockERC20(asset).balanceOf(user), amount, "User should have all of the assets after handleBatches");
    }

    function testRedeemETH() external {
        address[] memory assets = new address[](1);
        assets[0] = TransferLibrary.ETH;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH));
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH)));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(1e4, 1e4, 0, 0);

        uint24 depositFeeD6 = deployment.feeManager.depositFeeD6();
        uint24 redeemFeeD6 = deployment.feeManager.redeemFeeD6();

        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        uint224 amount = 1 ether;
        address user = vm.createWallet("user").addr;
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        assertEq(
            depositQueue.claimableOf(user),
            uint256(1e6 - depositFeeD6) * amount / 1e6,
            "Claimable amount should match the deposited amount"
        );

        depositQueue.claim(user);
        uint256 shares = deployment.shareManager.sharesOf(user);
        assertEq(shares, uint256(1e6 - depositFeeD6) * amount / 1e6, "User should have shares after claiming");

        vm.prank(user);
        redeemQueue.redeem(shares);

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp);

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        redeemQueue.handleBatches(1);

        assertEq(user.balance, 0, "User should have no ETH before claim");

        vm.prank(user);
        redeemQueue.claim(user, timestamps);

        assertEq(
            user.balance,
            uint256(1e6 - redeemFeeD6) * uint256(1e6 - depositFeeD6) * amount / 1e12,
            "User should have 1 ETH after claim"
        );

        address feeRecipient = deployment.feeManager.feeRecipient();

        shares = deployment.shareManager.sharesOf(feeRecipient);
        vm.prank(feeRecipient);
        redeemQueue.redeem(shares);
        timestamps[0] = uint32(block.timestamp);

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        redeemQueue.handleBatches(1);

        vm.prank(feeRecipient);
        redeemQueue.claim(feeRecipient, timestamps);
        assertEq(
            feeRecipient.balance,
            /// @dev Fee accrued (deposit and redeem) only on User's shares, not on the feeRecipient shares
            amount * depositFeeD6 / 1e6 + (1e6 - depositFeeD6) * amount * redeemFeeD6 / 1e12,
            "FeeRecipient should have expected ETH balance after claim"
        );
    }

    function testRedeemFee() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 priceD18 = 1e18;
        uint24 redeemFeeD6 = 1e5; // 10% fee

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, redeemFeeD6, 0, 0);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, depositQueue);
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        depositQueue.claim(user);
        uint256 shares = deployment.shareManager.sharesOf(user);

        assertEq(shares, amount * priceD18 / 1e18, "User should have shares after claim");

        uint32 redeemTimestamp = uint32(block.timestamp);
        vm.prank(user);
        redeemQueue.redeem(shares);

        assertEq(deployment.shareManager.sharesOf(user), 0, "User should have no shares after redeem");
        assertEq(MockERC20(asset).balanceOf(user), 0, "User should have no assets before claim");

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        redeemQueue.handleBatches(1);

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = redeemTimestamp;
        vm.prank(user);
        uint256 assets = redeemQueue.claim(user, timestamps);

        assertEq(assets, amount * (1e6 - redeemFeeD6) / 1e6, "User should have 90% of the assets after claim");
        assertEq(
            MockERC20(asset).balanceOf(user),
            amount * (1e6 - redeemFeeD6) / 1e6,
            "User should have 90% of the assets after claim"
        );
        assertEq(deployment.shareManager.sharesOf(user), 0, "User should have no shares after claim");
        assertEq(
            deployment.shareManager.sharesOf(deployment.feeManager.feeRecipient()),
            shares / 10,
            "Fee recipient should have 10% of the assets"
        );
    }

    function testFuzzMultipleRedeemQueues(int16[10] calldata amountDeviation) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();
        uint256 queueCount = amountDeviation.length;

        RedeemQueue[] memory redeemQueues = new RedeemQueue[](queueCount);
        uint224[] memory amounts = new uint224[](queueCount);
        for (uint256 index = 0; index < queueCount; index++) {
            redeemQueues[index] = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
            amounts[index] = _applyDeltaX16(1 ether, amountDeviation[index]);
        }

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(int256(1 ether * queueCount * 10)); // Set a high vault limit to allow all deposits

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        uint224 price = 1e18;
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        address[] memory users = new address[](queueCount);
        uint32[] memory userRedeemTimestamps = new uint32[](queueCount);

        for (uint256 i = 0; i < queueCount; i++) {
            users[i] = address(uint160(uint256(keccak256(abi.encode("user", i)))) >> 8);
            makeDeposit(users[i], amounts[i], depositQueue);
        }

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        for (uint256 i = 0; i < queueCount; i++) {
            assertTrue(depositQueue.claim(users[i]));
            assertEq(
                deployment.shareManager.sharesOf(users[i]),
                amounts[i] * price / 1e18,
                "User should have shares after claim"
            );
        }

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        for (uint256 i = 0; i < queueCount; i++) {
            vm.prank(users[i]);
            redeemQueues[i].redeem(amounts[i]);
            userRedeemTimestamps[i] = uint32(block.timestamp);
        }

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        for (uint256 i = 0; i < queueCount; i++) {
            redeemQueues[i].handleBatches(1);
            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = userRedeemTimestamps[i];
            vm.prank(users[i]);
            uint256 assets = redeemQueues[i].claim(users[i], timestamps);
            assertApproxEqAbs(assets * price / 1e18, amounts[i], 2, "User should receive assets after claim");
        }
    }

    function testFuzzMultipleRedeemQueuesDifferentAssets(int16[10] calldata amountDeviation) external {
        uint256 queueCount = amountDeviation.length;
        address[] memory assets = new address[](queueCount);
        uint224[] memory amounts = new uint224[](queueCount);
        uint32[] memory userRedeemTimestamps = new uint32[](queueCount);
        RedeemQueue[] memory redeemQueues = new RedeemQueue[](queueCount);

        for (uint256 index = 0; index < queueCount; index++) {
            assets[index] = address(new MockERC20());
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assets[0]));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount;
        for (uint256 index = 0; index < queueCount; index++) {
            redeemQueues[index] = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, assets[index])));
            amounts[index] = _applyDeltaX16(1 ether, amountDeviation[index]);
            amount += amounts[index];
        }

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(int256(1 ether * queueCount * 10)); // Set a high vault limit to allow all deposits

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        uint224 price = 1e18;
        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: price}));

        address user = vm.createWallet("user").addr;

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: assets[0], priceD18: price}));

        assertTrue(depositQueue.claim(user));
        assertEq(deployment.shareManager.sharesOf(user), amount * price / 1e18, "User should have shares after claim");

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));

        for (uint256 i = 0; i < queueCount; i++) {
            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: price}));
            vm.prank(user);
            redeemQueues[i].redeem(amounts[i]);
            userRedeemTimestamps[i] = uint32(block.timestamp);
        }

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        uint32[] memory timestamps = new uint32[](1);

        for (uint256 i = 0; i < queueCount; i++) {
            /// @dev Increase liquid assets in the vault to ensure redeem can be processed
            MockERC20(assets[i]).mint(address(deployment.vault), amounts[i] * 2);

            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: price}));
            assertEq(redeemQueues[i].handleBatches(1), 1, "Should handle one batch for each queue");
            timestamps[0] = userRedeemTimestamps[i];

            vm.prank(user);
            uint256 assetsAmountExpected = redeemQueues[i].claim(user, timestamps);

            assertApproxEqAbs(
                assetsAmountExpected * price / 1e18, amounts[i], 2, "User should receive assets after claim"
            );
        }
    }

    function testFuzzRedeem(uint16[200] calldata shareDelta, int16[200] calldata priceDelta) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0); // Set fees to zero

        address user = vm.createWallet("user").addr;
        uint256 amount = 100 ether;
        uint224 priceD18 = 1e18;

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(int256(amount * priceD18 / 1e18));

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        depositQueue.claim(user);
        uint256 sharesTotal = deployment.shareManager.sharesOf(user);
        assertEq(sharesTotal, amount * priceD18 / 1e18, "User should have shares after claim");
        uint32[] memory timestamps = new uint32[](1);

        uint256 denominator;
        for (uint256 index = 0; index < shareDelta.length; index++) {
            denominator += shareDelta[index];
        }
        uint256 redeemShare;
        for (uint256 index = 0; index < shareDelta.length; index++) {
            priceD18 = _applyDeltaX16Price(priceD18, priceDelta[index], securityParams);

            uint256 shareRemaining = deployment.shareManager.sharesOf(user);
            if (index == shareDelta.length - 1) {
                redeemShare = shareRemaining; // Redeem all remaining shares in the last iteration
            } else {
                redeemShare = sharesTotal * uint256(shareDelta[index]) / denominator;
                redeemShare = redeemShare == 0 ? sharesTotal / 100 : redeemShare; // Ensure at least 1% share is redeemed
                redeemShare = redeemShare > shareRemaining ? shareRemaining : redeemShare;
            }

            {
                // Ensure enough assets are available for redeem
                uint256 assetsAvailable = MockERC20(asset).balanceOf(address(deployment.vault));
                if (redeemShare > assetsAvailable * priceD18 / 1e18) {
                    redeemShare = assetsAvailable * priceD18 / 1e18;
                }
            }

            if (redeemShare == 0) {
                break;
            }

            vm.prank(user);
            redeemQueue.redeem(redeemShare);
            timestamps[0] = uint32(block.timestamp);

            skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

            redeemQueue.handleBatches(1);
            vm.prank(user);
            uint256 assets = redeemQueue.claim(user, timestamps);
            assertApproxEqAbs(assets * priceD18 / 1e18, redeemShare, 3, "User should receive assets after claim");
        }

        assertTrue(
            deployment.shareManager.sharesOf(user) < shareDelta.length
                || MockERC20(asset).balanceOf(address(deployment.vault)) < shareDelta.length,
            "User should have no shares or Vault should have no assets"
        );
    }

    function testRedeemInterval() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        uint224 amount = 1 ether;

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user1 = vm.createWallet("user1").addr;
        address user2 = vm.createWallet("user2").addr;

        makeDeposit(user1, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        makeDeposit(user2, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        depositQueue.claimableOf(user1);

        assertTrue(depositQueue.claim(user1));
        assertEq(deployment.shareManager.activeSharesOf(user1), amount, "User1 should have shares after claiming");

        assertTrue(depositQueue.claim(user2));
        assertEq(deployment.shareManager.activeSharesOf(user2), amount, "User2 should have shares after claiming");

        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        skip(securityParams.timeout);

        uint32[] memory timestamps = new uint32[](1);

        vm.prank(user1);
        redeemQueue.redeem(amount);
        uint32 redeemTimestamp1 = uint32(block.timestamp);

        skip(securityParams.redeemInterval);

        vm.prank(user2);
        redeemQueue.redeem(amount);
        uint32 redeemTimestamp2 = uint32(block.timestamp);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        redeemQueue.handleBatches(1);

        timestamps[0] = redeemTimestamp1;
        vm.prank(user1);
        redeemQueue.claim(user1, timestamps);

        assertEq(deployment.shareManager.sharesOf(user1), 0, "User1 should have no shares after redeem");
        assertEq(deployment.shareManager.sharesOf(user2), 0, "User2 should have no shares after redeem");

        timestamps[0] = redeemTimestamp2;
        vm.prank(user2);
        redeemQueue.claim(user2, timestamps); // `claim` is no-op for user2, redeem interval was not reached

        assertEq(MockERC20(asset).balanceOf(user1), amount, "User1 should have all of the assets after redeem");
        assertEq(MockERC20(asset).balanceOf(user2), 0, "User2 should not have any assets after redeem");

        // Another report & batch handling, now user2 should have all of the assets after redeem
        {
            skip(securityParams.timeout);

            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
            redeemQueue.handleBatches(1);

            timestamps[0] = redeemTimestamp2;
            vm.prank(user2);
            redeemQueue.claim(user2, timestamps);

            assertEq(MockERC20(asset).balanceOf(user2), amount, "User2 should have all of the assets after redeem");
        }
    }

    function testRedeemInterval_Claimable() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        uint224 amount = 1 ether;

        address userA = vm.createWallet("userA").addr;
        giveAssetsToUserAndApprove(userA, amount * 10, address(depositQueue));

        address userB = vm.createWallet("userB").addr;
        giveAssetsToUserAndApprove(userB, amount * 10, address(depositQueue));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDeposit(userA, amount, depositQueue);
        makeDeposit(userB, amount, depositQueue);

        // After this report, both users are eligible to claim shares from the deposit queue
        {
            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            assertEq(depositQueue.claimableOf(userA), amount, "userA claimable should be the deposited amount");
            assertEq(depositQueue.claimableOf(userB), amount, "userB claimable should be the deposited amount");

            assertTrue(depositQueue.claim(userA));
            assertEq(deployment.shareManager.activeSharesOf(userA), amount, "userA should have shares after claiming");

            assertTrue(depositQueue.claim(userB));
            assertEq(deployment.shareManager.activeSharesOf(userB), amount, "userB should have shares after claiming");
        }

        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        // Reedem as userA
        vm.prank(userA);
        redeemQueue.redeem(amount);
        uint32 redeemTimestamp_userA = uint32(block.timestamp);

        // Skip almost to the next report
        skip(securityParams.timeout - 1);

        // Reedem as userB
        vm.prank(userB);
        redeemQueue.redeem(amount);
        uint32 redeemTimestamp_userB = uint32(block.timestamp);

        // After this report, only userA is eligible to claim shares from the redeem queue
        // Because there is not enough time passed to make userB eligible.
        {
            skip(1);

            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
            redeemQueue.handleBatches(1);

            uint32[] memory timestamps = new uint32[](1);

            timestamps[0] = redeemTimestamp_userA;
            vm.prank(userA);
            uint256 userAClaimed = redeemQueue.claim(userA, timestamps);

            timestamps[0] = redeemTimestamp_userB;
            vm.prank(userB);
            uint256 userBClaimed = redeemQueue.claim(userB, timestamps);

            assertEq(userAClaimed, amount, "userA should have claimed all of the assets");
            assertEq(userBClaimed, 0, "userB should not have claimed any assets");
        }

        // After this report, userA should not have claimed any assets, it's already claimed.
        // UserB should claim all of the assets.
        {
            skip(securityParams.timeout);

            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
            redeemQueue.handleBatches(1);

            uint32[] memory timestamps = new uint32[](1);

            timestamps[0] = redeemTimestamp_userA;
            vm.prank(userA);
            uint256 userAClaimed = redeemQueue.claim(userA, timestamps);

            timestamps[0] = redeemTimestamp_userB;
            vm.prank(userB);
            uint256 userBClaimed = redeemQueue.claim(userB, timestamps);

            assertEq(userAClaimed, 0, "userA should not have claimed any assets, already claimed");
            assertEq(userBClaimed, amount, "userB should have claimed all of the assets, redeem interval passed");
        }
    }

    function testFuzzMultipleBatches(uint8[] calldata batchSizes, uint8 unhandledBatchesLimit) external {
        vm.assume(batchSizes.length > 0 && batchSizes.length <= 64);
        uint256 userCount;
        for (uint256 i = 0; i < batchSizes.length; i++) {
            userCount += batchSizes[i];
        }
        vm.assume(userCount > 0 && userCount <= 1024);
        if (unhandledBatchesLimit > batchSizes.length) {
            unhandledBatchesLimit = uint8(batchSizes.length);
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(int256(1 ether * userCount * 10)); // Set a high vault limit to allow all deposits

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        uint224 price = 1e18;
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        address[] memory users = new address[](userCount);
        uint32[] memory userRedeemTimestamps = new uint32[](userCount);
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < userCount; i++) {
            users[i] = address(uint160(uint256(keccak256(abi.encode("user", i)))) >> 8);
            makeDeposit(users[i], amount, depositQueue);
        }

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        for (uint256 i = 0; i < userCount; i++) {
            depositQueue.claim(users[i]);
            assertEq(
                deployment.shareManager.sharesOf(users[i]), amount * price / 1e18, "User should have shares after claim"
            );
        }

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));

        uint256 batchSize;
        uint256 unhandledBatches;
        uint256 batchIterator;

        for (uint256 i = 0; i < userCount; i++) {
            vm.prank(users[i]);
            redeemQueue.redeem(amount);
            userRedeemTimestamps[i] = uint32(block.timestamp);

            batchSize++;

            if (batchSize == batchSizes[batchIterator]) {
                skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
                pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));
                batchIterator++;
                unhandledBatches++;
                batchSize = 0;
            }

            if (unhandledBatches >= unhandledBatchesLimit) {
                assertEq(redeemQueue.handleBatches(unhandledBatches), unhandledBatches, "Should handle all batches");
                unhandledBatches = 0;
            }
        }
        if (unhandledBatches > 0) {
            skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));
            assertEq(redeemQueue.handleBatches(unhandledBatches), unhandledBatches, "Should handle all batches");
        }

        if (batchSize > 0) {
            skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: price}));
            assertEq(redeemQueue.handleBatches(1), 1, "Should handle all batches");
        }

        uint32[] memory timestamps = new uint32[](1);
        for (uint256 i = 0; i < userCount; i++) {
            timestamps[0] = userRedeemTimestamps[i];
            vm.prank(users[i]);
            uint256 assets = redeemQueue.claim(users[i], timestamps);
            assertEq(assets * price / 1e18, amount, "User should receive assets after claim");
        }
    }

    function testRedeemAfterRemovingERC20() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        (, uint256 shares) = depositQueue.requestOf(user);
        uint32 redeemTimestamp = uint32(block.timestamp);

        // during redeeming, all unclaimed shares are claimed
        vm.prank(user);
        redeemQueue.redeem(shares);

        assertEq(deployment.shareManager.sharesOf(user), 0, "User should have no shares after redeem");
        assertEq(IERC20(asset).balanceOf(user), 0, "User should have no assets before claim");

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = redeemTimestamp;

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(IERC20(asset).balanceOf(user), 0, "User should have no assets before handleBatches");

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertFalse(redeemQueue.canBeRemoved(), "RedeemQueue should not be removable before unhandled batches");
        redeemQueue.handleBatches(1);
        assertTrue(redeemQueue.canBeRemoved(), "RedeemQueue should be removable after all batches handled");

        assertEq(
            IERC20(asset).balanceOf(address(redeemQueue)), amount, "RedeemQueue should have assets after handleBatches"
        );

        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.grantRole(deployment.vault.REMOVE_QUEUE_ROLE(), deployment.vaultAdmin);
        deployment.vault.removeQueue(address(redeemQueue));
        vm.stopPrank();
        assertEq(IERC20(asset).balanceOf(address(redeemQueue)), amount, "RedeemQueue should have assets after removing");

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(deployment.shareManager.sharesOf(user), 0, "User should not have of the shares after claim");
        assertEq(IERC20(asset).balanceOf(user), amount, "User should have of the assets after claiming");
        assertEq(IERC20(asset).balanceOf(address(redeemQueue)), 0, "RedeemQueue should have no assets after claiming");
    }

    function testRedeemAfterRemovingETH() external {
        asset = TransferLibrary.ETH;
        assetsDefault = new address[](1);
        assetsDefault[0] = asset;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        RedeemQueue redeemQueue = RedeemQueue(payable(addRedeemQueue(deployment, vaultProxyAdmin, asset)));
        DepositQueue depositQueue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.feeManager.setFees(0, 0, 0, 0);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, depositQueue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        (, uint256 shares) = depositQueue.requestOf(user);
        uint32 redeemTimestamp = uint32(block.timestamp);

        // during redeeming, all unclaimed shares are claimed
        vm.prank(user);
        redeemQueue.redeem(shares);

        assertEq(deployment.shareManager.sharesOf(user), 0, "User should have no shares after redeem");
        assertEq(user.balance, 0, "User should have no assets before claim");

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = redeemTimestamp;

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(user.balance, 0, "User should have no assets before handleBatches");

        skip(Math.max(securityParams.timeout, securityParams.redeemInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertFalse(redeemQueue.canBeRemoved(), "RedeemQueue should not be removable before unhandled batches");
        redeemQueue.handleBatches(1);
        assertTrue(redeemQueue.canBeRemoved(), "RedeemQueue should be removable after all batches handled");

        assertEq(address(redeemQueue).balance, amount, "RedeemQueue should have assets after handleBatches");

        vm.startPrank(deployment.vaultAdmin);
        deployment.vault.grantRole(deployment.vault.REMOVE_QUEUE_ROLE(), deployment.vaultAdmin);
        deployment.vault.removeQueue(address(redeemQueue));
        vm.stopPrank();
        assertEq(address(redeemQueue).balance, amount, "RedeemQueue should have assets after removing");

        vm.prank(user);
        redeemQueue.claim(user, timestamps);
        assertEq(deployment.shareManager.sharesOf(user), 0, "User should not have of the shares after claim");
        assertEq(user.balance, amount, "User should have of the assets after claiming");
        assertEq(address(redeemQueue).balance, 0, "RedeemQueue should have no assets after claiming");
    }
}
