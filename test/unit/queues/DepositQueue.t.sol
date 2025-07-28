// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract DepositQueueTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address asset;
    address[] assetsDefault;

    function setUp() external {
        asset = address(new MockERC20());
        assetsDefault.push(asset);
    }

    function testDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount = 1 ether;

        vm.expectRevert(abi.encodeWithSelector(IQueue.ZeroValue.selector));
        queue.deposit(0, address(0), new bytes32[](0));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        giveAssetsToUserAndApprove(user, amount, address(queue));

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));

        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, block.timestamp, "Timestamp should match current block timestamp");
        assertEq(assets, amount, "Assets should match the deposited amount");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.PendingRequestExists.selector));
        queue.deposit(amount, address(0), new bytes32[](0));

        /// @dev update the price
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");
    }

    function testDepositETH() external {
        address[] memory assets = new address[](1);
        assets[0] = TransferLibrary.ETH;

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, TransferLibrary.ETH));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        uint224 amount = 1 ether;
        address user = vm.createWallet("user").addr;
        makeDeposit(user, amount, queue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: TransferLibrary.ETH, priceD18: 1e18}));

        assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");

        queue.claim(user);
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after claiming");
    }

    function testDepositInterval() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount = 1 ether;

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user1 = vm.createWallet("user1").addr;
        address user2 = vm.createWallet("user2").addr;

        skip(securityParams.timeout);
        makeDeposit(user1, amount, queue);

        skip(securityParams.depositInterval);
        makeDeposit(user2, amount, queue);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        queue.claimableOf(user1);

        assertTrue(queue.claim(user1));
        assertEq(deployment.shareManager.activeSharesOf(user1), amount, "User1 should have shares after claiming");

        /// @dev user2 has not claimed yet, so they should not have shares
        assertFalse(queue.claim(user2));
        assertEq(deployment.shareManager.activeSharesOf(user2), 0, "User2 should have shares after claiming");
    }

    function testDepositInterval_Claimable() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount = 1 ether;

        address userA = vm.createWallet("userA").addr;
        giveAssetsToUserAndApprove(userA, amount * 10, address(queue));

        address userB = vm.createWallet("userB").addr;
        giveAssetsToUserAndApprove(userB, amount * 10, address(queue));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        vm.prank(userA);
        queue.deposit(amount, address(0), new bytes32[](0));

        skip(securityParams.timeout - 1);

        vm.prank(userB);
        queue.deposit(amount, address(0), new bytes32[](0));

        // After this report, only userA is eligible to claim, userB is not (due to deposit interval)
        {
            skip(1);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            assertEq(queue.claimableOf(userA), amount, "userA claimable should be the deposited amount");
            assertEq(queue.claimableOf(userB), 0, "userB claimable should be zero");
        }

        // After this report, both users are eligible to claim
        {
            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            assertEq(queue.claimableOf(userA), amount, "userA claimable should be the deposited amount");
            assertEq(queue.claimableOf(userB), amount, "userB claimable should be the deposited amount");
        }
    }

    function testDepositLimitExceeded() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 amount = 1 ether;
        uint224 priceD18 = 1e18; // initial price
        int256 vaultLimit = 0;

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(vaultLimit); // Set vault limit to zero

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));
        address user = vm.createWallet("user").addr;
        giveAssetsToUserAndApprove(user, 10 * amount, address(queue));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.LimitExceeded.selector, amount, vaultLimit));
        queue.deposit(amount, address(0), new bytes32[](0));

        vaultLimit = 1.5 ether;
        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(vaultLimit); // Reset vault limit

        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        queue.claim(user);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRiskManager.LimitExceeded.selector, 2 * amount, vaultLimit));
        queue.deposit(amount, address(0), new bytes32[](0));
    }

    function testFuzzDepositsOneUser(int16[100] calldata amountDeviation, int16[100] calldata deltaPrice) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 priceD18 = 1e18; // initial price

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        address user = vm.createWallet("user").addr;
        uint224[] memory amounts = new uint224[](amountDeviation.length);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        giveAssetsToUserAndApprove(user, 1e6 ether, address(queue));

        uint224 shareTotal;

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
            vm.prank(user);
            queue.deposit(amounts[i], address(0), new bytes32[](0));
            assertFalse(queue.canBeRemoved(), "Queue should not be removable yet");

            priceD18 = _applyDeltaX16Price(priceD18, deltaPrice[i], securityParams);

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

            uint224 shareExpected = amounts[i] * priceD18 / 1e18;

            shareTotal += shareExpected;
            assertEq(queue.claimableOf(user), shareExpected, "Claimable amount should match the deposited amount");

            queue.claim(user);
            assertTrue(queue.canBeRemoved(), "Queue should be removable now");

            assertEq(deployment.shareManager.activeSharesOf(user), shareTotal, "User should have shares after claiming");
            assertEq(
                deployment.shareManager.activeShares(), shareTotal, "Vault should have active shares after claiming"
            );
        }
    }

    function testFuzzDepositsMultipleUsers(int16[256] calldata amountDeviation, int16[256] calldata deltaPrice)
        external
    {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        uint224 priceD18 = 1e18; // initial price

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        address[] memory user = new address[](amountDeviation.length);
        for (uint256 i = 0; i < amountDeviation.length; i++) {
            user[i] = address(uint160(uint256(keccak256(abi.encodePacked("user", i)))));
        }

        uint224[] memory amounts = new uint224[](amountDeviation.length);
        uint224[] memory shareExpected = new uint224[](amountDeviation.length);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
            makeDeposit(user[i], amounts[i], queue);
            assertFalse(queue.canBeRemoved(), "Queue should not be removable yet");

            priceD18 = _applyDeltaX16Price(priceD18, deltaPrice[i], securityParams);

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

            shareExpected[i] = amounts[i] * priceD18 / 1e18;

            assertEq(queue.claimableOf(user[i]), shareExpected[i], "Claimable amount should match the deposited amount");
        }

        uint224 shareTotal;
        for (uint256 i = 0; i < amountDeviation.length; i++) {
            queue.claim(user[i]);
            assertTrue(queue.canBeRemoved(), "Queue should be removable now");

            assertEq(
                deployment.shareManager.activeSharesOf(user[i]),
                shareExpected[i],
                "User should have shares after claiming"
            );

            shareTotal += shareExpected[i];

            assertEq(
                deployment.shareManager.activeShares(), shareTotal, "Vault should have active shares after claiming"
            );
        }
    }

    function testFuzzDepositMultipleQueuesSingleAsset(
        int16[100] calldata amountDeviation,
        uint16 initPriceD6,
        int16 deltaPrice
    ) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        uint256 queueLength = amountDeviation.length;
        DepositQueue[] memory queues = new DepositQueue[](queueLength);
        uint224[] memory amounts = new uint224[](queueLength);

        for (uint256 i = 0; i < queueLength; i++) {
            queues[i] = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
        }
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();
        uint224 initPriceD18 = uint224(1 ether + uint224(initPriceD6) * 1e12); // Convert to D18

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: initPriceD18}));
        address user = vm.createWallet("user").addr;
        for (uint256 i = 0; i < queueLength; i++) {
            makeDeposit(user, amounts[i], queues[i]);
            assertEq(queues[i].claimableOf(user), 0, "Claimable amount should be zero before deposit");
        }

        uint224 priceD18 = _applyDeltaX16Price(initPriceD18, deltaPrice, securityParams);
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceD18}));

        uint224 totalShare;
        for (uint256 i = 0; i < queueLength; i++) {
            totalShare += amounts[i] * priceD18 / 1e18;
        }
        assertEq(
            deployment.shareManager.claimableSharesOf(user),
            totalShare,
            "Claimable amount should match the deposited amount"
        );

        deployment.shareManager.claimShares(user);
        assertEq(deployment.shareManager.activeSharesOf(user), totalShare, "User should have shares after claiming");
        assertEq(
            deployment.shareManager.claimableSharesOf(user), 0, "User should have no claimable shares after claiming"
        );
    }

    function testFuzzDepositMultipleQueuesMultipleAssets(
        int16[10] calldata amountDeviation,
        int16[10] calldata deltaPrice
    ) external {
        uint256 assetsLength = amountDeviation.length;
        address[] memory assets = new address[](assetsLength);
        uint224[] memory priceInit = new uint224[](assetsLength);
        uint224[] memory amounts = new uint224[](assetsLength);
        DepositQueue[] memory queue = new DepositQueue[](assetsLength);

        for (uint256 i = 0; i < assetsLength; i++) {
            assets[i] = address(new MockERC20());
            priceInit[i] = 1e18; // Initial price for each asset
            amounts[i] = _applyDeltaX16(1e18, amountDeviation[i]); // Amount to deposit for each asset
        }

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        address user = vm.createWallet("user").addr;

        for (uint256 i = 0; i < assetsLength; i++) {
            queue[i] = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, assets[i]));
            /// @dev push a report to set the initial price
            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: priceInit[i]}));
        }

        for (uint256 i = 0; i < assetsLength; i++) {
            makeDeposit(user, amounts[i], queue[i]);
            assertEq(queue[i].claimableOf(user), 0, "Claimable amount should be zero before deposit");
        }

        /// @dev update the price
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));

        uint224 priceCurrent;
        uint224 shareTotal;
        uint224 shareExpected;
        for (uint256 i = 0; i < assetsLength; i++) {
            priceCurrent = _applyDeltaX16Price(priceInit[i], deltaPrice[i], securityParams); // Current price for each asset
            pushReport(deployment, IOracle.Report({asset: assets[i], priceD18: priceCurrent}));
            shareExpected = amounts[i] * priceCurrent / 1e18;
            shareTotal += shareExpected;
            assertEq(queue[i].claimableOf(user), shareExpected, "User should have shares after claiming");
        }

        /// @dev claim all shares for the user from all queues
        deployment.shareManager.claimShares(user);

        for (uint256 i = 0; i < assetsLength; i++) {
            assertEq(queue[i].claimableOf(user), 0, "Claimable amount should be zero after claiming");
        }

        assertEq(
            deployment.shareManager.activeSharesOf(user), shareTotal, "User should have total shares after claiming"
        );
    }

    function testClaim() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;

        makeDeposit(user, amount, queue);

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");
        assertEq(deployment.shareManager.activeSharesOf(user), 0, "User should have no shares before the price update");
        assertEq(
            deployment.shareManager.claimableSharesOf(user),
            0,
            "User should have no claimable shares before the price update"
        );

        /// @dev try to do claim
        assertFalse(queue.claim(user), "Claim should fail before the price update");

        /// @dev update the price
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");
        assertEq(deployment.shareManager.activeSharesOf(user), 0, "User should have no shares before claiming");
        assertEq(
            deployment.shareManager.claimableSharesOf(user), amount, "User should have claimable shares before claiming"
        );

        /// @dev do actual claim
        assertTrue(queue.claim(user), "Claim should succeed after the price update");

        assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero after claiming");
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after claiming");
        assertEq(
            deployment.shareManager.claimableSharesOf(user), 0, "User should have no claimable shares after claiming"
        );
    }

    function testRemoveQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;

        makeDeposit(user, amount, queue);

        assertFalse(queue.canBeRemoved(), "Queue should not be removable yet");

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertTrue(queue.canBeRemoved(), "Queue should be removable after claimable request");

        vm.startPrank(vaultAdmin);
        deployment.vault.grantRole(deployment.vault.REMOVE_QUEUE_ROLE(), vaultAdmin);
        deployment.vault.removeQueue(address(queue));
        vm.stopPrank();

        /// @notice it s known behavior that DepositQueue can be removed even if there are no claimable requests
        /// @notice role holder who can remove the queue should take care of this and should call permissionless claim before
        vm.expectRevert(abi.encodeWithSelector(IQueue.Forbidden.selector));
        queue.claim(user);

        deployment.shareManager.claimShares(user);
        assertEq(deployment.shareManager.activeSharesOf(user), 0, "User should not have shares after claiming");

        vm.prank(address(deployment.vault));
        deployment.shareManager.mintAllocatedShares(user, amount);
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares after claiming");
    }

    function testCancelSingleDepositRequest() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint256 amount = 1 ether;
        {
            /// @dev cancel before claimable
            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(IDepositQueue.NoPendingRequest.selector));
            queue.cancelDepositRequest();

            makeDeposit(user, amount, queue);
            assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

            (, uint256 assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should match the deposited amount");

            vm.prank(user);
            queue.cancelDepositRequest();

            (, assets) = queue.requestOf(user);
            assertEq(assets, 0, "Assets should be zero after canceling the request");
            assertEq(queue.claimableOf(user), 0, "Claimable amount should match the deposited amount");
        }

        {
            /// @dev cancel after claimable
            makeDeposit(user, amount, queue);
            assertEq(queue.claimableOf(user), 0, "Claimable amount should be zero before deposit");

            (, uint256 assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should match the deposited amount");

            skip(Math.max(securityParams.timeout, securityParams.depositInterval));
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

            vm.prank(user);
            vm.expectRevert(abi.encodeWithSelector(IDepositQueue.ClaimableRequestExists.selector));
            queue.cancelDepositRequest();

            (, assets) = queue.requestOf(user);
            assertEq(assets, amount, "Assets should not be zero because the request is claimable");
            assertEq(queue.claimableOf(user), amount, "Claimable amount should match the deposited amount");
        }
    }

    function testFuzzCancelMultipleDepositRequests(
        int16 priceDeviation,
        int16[256] calldata amountDeviation,
        bool[256] calldata cancel
    ) external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        vm.prank(deployment.vaultAdmin);
        deployment.riskManager.setVaultLimit(1e6 ether);

        uint224 priceInit = _applyDeltaX16Price(1e18, priceDeviation, securityParams); // initial price

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceInit}));
        skip(securityParams.depositInterval);

        address[] memory users = new address[](amountDeviation.length);
        uint224[] memory amounts = new uint224[](amountDeviation.length);

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            amounts[i] = _applyDeltaX16(1 ether, amountDeviation[i]);
            users[i] = address(uint160(uint256(keccak256(abi.encodePacked("user", i)))));

            makeDeposit(users[i], amounts[i], queue);
        }

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            if (cancel[i]) {
                vm.prank(users[i]);
                queue.cancelDepositRequest();
            }
        }

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            assertEq(queue.claimableOf(users[i]), 0, "Claimable amount should be zero");
            if (cancel[i]) {
                assertEq(MockERC20(asset).balanceOf(users[i]), amounts[i], "User should receive the canceled amount");
            } else {
                assertEq(MockERC20(asset).balanceOf(users[i]), 0, "User should not receive any amount");
            }
        }

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: priceInit}));

        for (uint256 i = 0; i < amountDeviation.length; i++) {
            uint224 shareExpected = cancel[i] ? 0 : amounts[i] * priceInit / 1e18;
            assertEq(queue.claimableOf(users[i]), shareExpected, "Claimable amount should match the deposited amount");

            deployment.shareManager.claimShares(users[i]);

            assertEq(
                deployment.shareManager.activeSharesOf(users[i]),
                shareExpected,
                "Claimed amount should match the expected amount"
            );
        }
    }

    /// @notice Tests that the final amount of deposited assets is correct after various number of deposits and cancellations.
    function testDepositRequestAmountIntegrity(uint8 initialReports, uint8 users, uint8 cancels) external {
        vm.assume(initialReports > 0); // [1, 255]
        vm.assume(users > 1 && users <= 32); // [2, 32]
        vm.assume(cancels <= users); // [0, 32]

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push initial reports to check that the length of the "prices" list does not affect the calculation
        for (uint8 i = 0; i < initialReports; i++) {
            skip(securityParams.timeout);
            pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        }

        assertEq(IERC20(asset).balanceOf(address(deployment.vault)), 0);

        uint224 amount = 1 ether;

        for (uint8 i = 0; i < users; i++) {
            skip(1 minutes);

            address user = vm.addr(i + 1);
            makeDeposit(user, amount, queue);
        }

        for (uint8 i = 0; i < cancels; i++) {
            skip(1 minutes);

            address user = vm.addr(i + 1);
            vm.prank(user);
            queue.cancelDepositRequest();
        }

        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(IERC20(asset).balanceOf(address(deployment.vault)), amount * (users - cancels));
    }

    function testDepositPausedQueue() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;

        vm.startPrank(vaultAdmin);
        deployment.vault.grantRole(deployment.vault.SET_QUEUE_STATUS_ROLE(), vaultAdmin);
        deployment.vault.setQueueStatus(address(queue), true);
        vm.stopPrank();

        giveAssetsToUserAndApprove(user, amount, address(queue));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IQueue.QueuePaused.selector));
        queue.deposit(amount, address(0), new bytes32[](0));
    }

    function testDepositNotAllowed() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;

        vm.prank(vaultAdmin);
        deployment.shareManager.setFlags(
            IShareManager.Flags({
                hasMintPause: false,
                hasBurnPause: false,
                hasTransferPause: false,
                hasWhitelist: true,
                hasTransferWhitelist: false,
                globalLockup: 0
            })
        );

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: false,
                canTransfer: true,
                isBlacklisted: false
            })
        );

        giveAssetsToUserAndApprove(user, amount, address(queue));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IDepositQueue.DepositNotAllowed.selector));
        queue.deposit(amount, address(0), new bytes32[](0));

        vm.prank(vaultAdmin);
        deployment.shareManager.setAccountInfo(
            user,
            IShareManager.AccountInfo({
                canDeposit: true,
                canTransfer: true,
                isBlacklisted: false
            })
        );

        /// @dev just to make sure the deposit works after the account is allowed
        vm.prank(user);
        queue.deposit(amount, address(0), new bytes32[](0));
        (, uint256 assets) = queue.requestOf(user);
        assertEq(assets, amount, "Assets should match the deposited amount");
    }

    function testMintFees() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        FeeManager feeManager = deployment.feeManager;
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address user = vm.createWallet("user").addr;
        uint224 amount = 1 ether;
        uint24 depositFee = 1e4; // 0.01%

        makeDeposit(user, amount, queue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            0,
            "Fee recipient should have no shares in case of 0 fees"
        );

        vm.prank(vaultAdmin);
        feeManager.setFees(depositFee, 0, 0, 0);

        makeDeposit(user, amount, queue);

        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        assertEq(
            deployment.shareManager.activeSharesOf(feeManager.feeRecipient()),
            Math.mulDiv(uint256(amount), depositFee, 1e6),
            "Fee recipient should have shares based on deposit fee"
        );
        assertEq(deployment.shareManager.activeSharesOf(user), amount, "User should have shares based on deposit fee");
        assertEq(
            deployment.shareManager.activeShares(),
            Math.mulDiv(uint256(amount), depositFee + 1e6, 1e6),
            "User should have shares based on deposit fee"
        );
    }

    function testMultipleDeposit() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));
        IOracle.SecurityParams memory securityParams = deployment.oracle.securityParams();

        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address[] memory users = new address[](10);
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
            skip(i * 1 hours);
            makeDeposit(users[i], amount, queue);
            assertEq(queue.claimableOf(users[i]), 0, "Claimable amount should be zero");
        }
        skip(Math.max(securityParams.timeout, securityParams.depositInterval));
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(queue.claimableOf(users[i]), amount, "Claimable amount should not be zero");
        }
    }

    function testHandleReport() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 6e16,
            suspiciousAbsoluteDeviation: 2e16,
            maxRelativeDeviationD18: 4e16,
            suspiciousRelativeDeviationD18: 3e16,
            timeout: 1000,
            depositInterval: 3600,
            redeemInterval: 3600
        });

        vm.prank(deployment.vaultAdmin);
        deployment.oracle.setSecurityParams(securityParams);

        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
        address user1 = vm.createWallet("user1").addr;
        address user2 = vm.createWallet("user2").addr;
        address user3 = vm.createWallet("user3").addr;
        uint256 amount = 1 ether;

        makeDeposit(user1, amount, queue);

        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDeposit(user2, amount, queue);

        skip(securityParams.timeout);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        makeDeposit(user3, amount, queue);

        skip(securityParams.depositInterval - securityParams.timeout + 1);
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));
    }

    function testRequestsExtend() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        DepositQueue queue = DepositQueue(addDepositQueue(deployment, vaultProxyAdmin, asset));

        IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
            maxAbsoluteDeviation: 6e16,
            suspiciousAbsoluteDeviation: 2e16,
            maxRelativeDeviationD18: 4e16,
            suspiciousRelativeDeviationD18: 3e16,
            timeout: 1000,
            depositInterval: 3600,
            redeemInterval: 3600
        });

        vm.prank(deployment.vaultAdmin);
        deployment.oracle.setSecurityParams(securityParams);
        /// @dev push a report to set the initial price
        pushReport(deployment, IOracle.Report({asset: asset, priceD18: 1e18}));

        address[] memory users = new address[](17);
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
        }
        uint256 amount = 1 ether;
        for (uint256 i = 0; i < 16; i++) {
            users[i] = vm.createWallet(string(abi.encodePacked("user", i))).addr;
            skip(1 hours);
            makeDeposit(users[i], amount, queue);
            assertEq(queue.claimableOf(users[i]), 0, "Claimable amount should be zero");
        }

        skip(1 hours);
        makeDeposit(users[16], amount, queue);
        assertEq(queue.claimableOf(users[16]), 0, "Claimable amount should be zero");
    }
}
