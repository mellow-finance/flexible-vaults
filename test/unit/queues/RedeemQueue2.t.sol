// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract RedeemQueueTest2 is Test {
    address internal proxyAdmin = makeAddr("proxyAdmin");

    MockVault internal vault;

    address internal user;

    address internal assetAddress;
    address internal vaultAddress;

    RedeemQueue internal queue;

    uint32 constant REDEEM_INTERVAL = 1 hours;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------

    function setUp() public {
        user = makeAddr("user");

        vault = new MockVault();
        vault.addRiskManager(type(uint256).max);

        assetAddress = TransferLibrary.ETH;
        vaultAddress = address(vault);

        queue = _createQueue(assetAddress, vaultAddress);
    }

    // -----------------------------------------------------------------------
    // Constructor tests
    // -----------------------------------------------------------------------

    /// @notice Tests that derived storage slot for the parent `Queue` is unique
    function testConstructorSetsUniqueStorageSlotsForParentQueue() public view {
        uint256 version = 1;
        string memory moduleName = "Queue";
        string memory name = "MockRedeemQueue";

        // Ensure the storage slot is set correctly
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedAsset = _loadAddressFromSlot(address(queue), moduleSlot);
            assertEq(storedAsset, assetAddress, "Asset address mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, 0);
            address storedAsset = _loadAddressFromSlot(address(queue), moduleSlot);
            assertEq(storedAsset, address(0), "Asset should be unset for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, "", version);
            address storedAsset = _loadAddressFromSlot(address(queue), moduleSlot);
            assertEq(storedAsset, address(0), "Asset should be unset for different name");
        }
    }

    /// @notice Tests that derived storage slot for the `RedeemQueue` is unique
    function testConstructorSetsUniqueStorageSlotsForRedeemQueue() public {
        uint256 version = 1;
        string memory moduleName = "RedeemQueue";
        string memory name = "MockRedeemQueue";

        // Increment `handledIndices` by pushing a dummy report
        {
            skip(REDEEM_INTERVAL);
            _pushReport(1e18);
        }

        // Ensure the storage slot is set correctly
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, version);
            uint256 handledIndices = _loadUintFromSlot(address(queue), moduleSlot);
            assertEq(handledIndices, 1, "Handled indices should be 1");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, 0);
            uint256 handledIndices = _loadUintFromSlot(address(queue), moduleSlot);
            assertEq(handledIndices, 0, "Handled indices should be 0");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, "", version);
            uint256 handledIndices = _loadUintFromSlot(address(queue), moduleSlot);
            assertEq(handledIndices, 0, "Handled indices should be 0");
        }
    }

    // -----------------------------------------------------------------------
    // Misc view function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `vault()` returns expected value after initialization.
    function testVaultReturnExpectedValue() public view {
        assertEq(queue.vault(), vaultAddress);
    }

    /// @notice Tests that `asset()` returns expected value after initialization.
    function testAssetReturnExpectedValue() public view {
        assertEq(queue.asset(), assetAddress);
    }

    /// @notice Tests that `getState()` returns the initial expected values.
    function testGetStateReturnsInitialValues() public view {
        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Initial batchIterator should be 0");
        assertEq(batches, 0, "Initial batches length should be 0");
        assertEq(totalDemandAssets, 0, "Initial totalDemandAssets should be 0");
        assertEq(totalPendingShares, 0, "Initial totalPendingShares should be 0");
    }

    /// @notice Tests that `batchAt` returns zero values for an out-of-bounds index.
    function testBatchAtReturnsZeroForInvalidIndex(uint32 index) public view {
        (uint256 assets, uint256 shares) = queue.batchAt(index);
        assertEq(assets, 0);
        assertEq(shares, 0);
    }

    // -----------------------------------------------------------------------
    // requestsOf() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `requestsOf` returns an empty array for a new user.
    function testRequestsOfReturnsEmptyForNewUser() public view {
        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 100);
        assertEq(requests.length, 0);
    }

    /// @notice Tests that `requestsOf` returns correct values for a user with a pending request.
    function testRequestsOfReturnsCorrectValuesForPendingRequest() public {
        _performRedeem(user, 1 ether);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 256);
        assertEq(requests.length, 1);
        assertEq(requests[0].shares, 1 ether);
        assertEq(requests[0].timestamp, uint32(block.timestamp));
    }

    /// @notice Tests that `requestsOf` returns correct values for a user with multiple requests (same timestamp).
    function testRequestsOfReturnsCorrectValuesForMultipleRequests() public {
        _performRedeem(user, 1 ether);
        _performRedeem(user, 2 ether);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 256);
        assertEq(requests.length, 1);
        assertEq(requests[0].shares, 3 ether);
        assertEq(requests[0].timestamp, uint32(block.timestamp));
    }

    /// @notice Tests that `requestsOf` returns correct values for a user with multiple requests (different timestamps).
    function testRequestsOfReturnsCorrectValuesForMultipleRequests_WithDifferentTimestamps() public {
        _performRedeem(user, 1 ether);

        skip(1);

        _performRedeem(user, 2 ether);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 256);
        assertEq(requests.length, 2);
        assertEq(requests[0].shares, 1 ether);
        assertEq(requests[0].timestamp, uint32(block.timestamp - 1));
        assertEq(requests[1].shares, 2 ether);
        assertEq(requests[1].timestamp, uint32(block.timestamp));
    }

    // -----------------------------------------------------------------------
    // redeem() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `redeem` reverts when `shares` is zero.
    function testRedeemRevertsOnZeroShares() public {
        vm.expectRevert(IQueue.ZeroValue.selector);
        _performRedeem(user, 0);
    }

    /// @notice Tests that `redeem` reverts when the queue is paused.
    function testRedeemRevertsWhenQueuePaused() public {
        vault.__setPausedQueue(address(queue));
        vm.expectRevert(IQueue.QueuePaused.selector);
        _performRedeem(user, 1 ether);
    }

    /// @notice Tests that a successful `redeem` burns shares and records the request.
    function testRedeemSuccess() public {
        // Expect the burn to be called
        vm.expectCall(address(vault.shareManager()), abi.encodeWithSelector(IShareManager.burn.selector, user, 1 ether));

        // Expect the emit of the event
        vm.expectEmit(true, true, true, true);
        emit IRedeemQueue.RedeemRequested(user, 1 ether, uint32(block.timestamp));

        _performRedeem(user, 1 ether);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 1);
        assertEq(requests.length, 1);
        assertEq(requests[0].shares, 1 ether);
        assertEq(requests[0].timestamp, uint32(block.timestamp));

        (,,, uint256 totalPendingShares) = queue.getState();
        assertEq(totalPendingShares, 1 ether, "Total pending shares should be 1 ether");
    }

    /// @notice Tests that `redeem` correctly handles the fees.
    function testRedeemCorrectlyHandlesFees() public {
        address feeRecipient = makeAddr("feeRecipient");

        MockFeeManager feeManager = vault.addFeeManager();
        feeManager.__setRedeemFeeInPercentage(10);
        feeManager.__setFeeRecipient(feeRecipient);

        // Expect the mint to be called
        vm.expectCall(
            address(vault.shareManager()),
            abi.encodeWithSelector(MockShareManager.mint.selector, feeRecipient, 0.1 ether)
        );

        _performRedeem(user, 1 ether);

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 1);
        assertEq(requests.length, 1);
        assertEq(requests[0].shares, 0.9 ether);
    }

    // -----------------------------------------------------------------------
    // handleReport() internal hook tests (invoked via public `handleReport` in Queue)
    // -----------------------------------------------------------------------

    /// @notice Tests that `handleReport` should not process if no requests were made.
    function testHandleReportDoesNotProcessIfNoRequestsWereMade() public {
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        // Initial "timestamp" item should be processed, i.e. `handledIndices` should be incremented
        bytes32 moduleSlot = SlotLibrary.getSlot("RedeemQueue", "MockRedeemQueue", 1);
        uint256 handledIndices = _loadUintFromSlot(address(queue), moduleSlot);
        assertEq(handledIndices, 1, "Handled indices should be 1");

        // No batches should be created
        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 0, "Batches length should be 0");
        assertEq(totalDemandAssets, 0, "Total demand assets should be 0");
        assertEq(totalPendingShares, 0, "Total pending shares should be 0");
    }

    /// @notice Tests that `handleReport` should create a batch and increase demand assets if a request was made.
    function testHandleReportCreatesBatchAndIncreasesDemandAssets() public {
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 1, "Batches length should be 1");
        assertEq(totalDemandAssets, 1 ether, "Total demand assets should be 1 ether");
        assertEq(totalPendingShares, 1 ether, "Total pending shares should be 1 ether");
    }

    /// @notice Tests that `handleReport` should create a batch and increase demand assets if multiple requests were made.
    function testHandleReportCreatesBatchAndIncreasesDemandAssets_WithMultipleRequests() public {
        _performRedeem(user, 1 ether);
        _performRedeem(user, 2 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 1, "Batches length should be 1");
        assertEq(totalDemandAssets, 3 ether, "Total demand assets should be 3 ether");
        assertEq(totalPendingShares, 3 ether, "Total pending shares should be 3 ether");
    }

    /// @notice Tests that `handleReport` correctly handles the case when the first redeem is made right after the queue is created.
    function testHandleReportCorrectlyHandlesFirstRedeemAfterQueueCreation() public {
        _performRedeem(user, 1 ether);

        skip(REDEEM_INTERVAL);

        _performRedeem(user, 2 ether);

        skip(1);

        _pushReport(1e18);

        // Check that only first request is processed, second request is not processed yet
        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 1, "Batches length should be 1");
        assertEq(totalDemandAssets, 1 ether, "Total demand assets should be 1 ether");
        assertEq(totalPendingShares, 3 ether, "Total pending shares should be 3 ether");
    }

    // -----------------------------------------------------------------------
    // handleBatches() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `handleBatches` processes a single batch correctly.
    function testHandleBatchesProcessesBatchCorrectly() public {
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        vault.__setLiquidAssets(1 ether);

        // Expect the call to the vault's risk manager
        vm.expectCall(
            address(vault.riskManager()),
            abi.encodeWithSelector(IRiskManager.modifyVaultBalance.selector, assetAddress, -int256(1 ether))
        );

        // Expect the call to the vault's redeem hook
        vm.expectCall(address(vault), abi.encodeWithSelector(IShareModule.callHook.selector, 1 ether));

        // Expect the emit of the event
        vm.expectEmit(true, true, true, true);
        emit IRedeemQueue.RedeemRequestsHandled(1, 1 ether);

        uint256 counter = queue.handleBatches(1);
        assertEq(counter, 1, "Counter should be 1");

        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 1, "Batch iterator should be 1");
        assertEq(batches, 1, "Batches length should be 1");

        // No demand assets should be left, vault have enough liquid assets
        assertEq(totalDemandAssets, 0, "Total demand assets should be 0");

        // No pending shares should be left, all shares have been redeemed
        assertEq(totalPendingShares, 0, "Total pending shares should be 0");
    }

    /// @notice Tests that `handleBatches` early-exits when no batches are available.
    function testHandleBatchesEarlyExitWhenNoBatches() public {
        // Initial state
        {
            (uint256 batchIterator, uint256 batches,,) = queue.getState();
            assertEq(batchIterator, 0, "Batch iterator should be 0");
            assertEq(batches, 0, "Batches length should be 0");
        }

        // Case A: No batches processed when argument is 0
        {
            uint256 counter = queue.handleBatches(0);
            assertEq(counter, 0, "Counter should be 0");
        }

        // Case B: No batches processed when argument is greater than the number of batches
        {
            uint256 counter = queue.handleBatches(1);
            assertEq(counter, 0, "Counter should be 0");
        }

        // Case C: No batches processed when there is no liquidity
        {
            vault.__setLiquidAssets(0);

            _performRedeem(user, 1 ether);
            skip(REDEEM_INTERVAL);
            _pushReport(1e18);

            uint256 counter = queue.handleBatches(1);
            assertEq(counter, 0, "Counter should be 0");
        }
    }

    /// @notice Tests that `handleBatches` handles partial liquidity scenarios.
    function testHandleBatchesHandlesPartialLiquidity() public {
        vault.__setLiquidAssets(1.5 ether);

        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        skip(1);

        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        // Check that the state is expected
        (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
            queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 2, "Batches length should be 2");
        assertEq(totalDemandAssets, 2 ether, "Total demand assets should be 2 ether");
        assertEq(totalPendingShares, 2 ether, "Total pending shares should be 2 ether");

        // Process the batches
        // Only one batch should be processed, because the vault has only 1.5 ether of liquid assets
        uint256 counter = queue.handleBatches(2);
        assertEq(counter, 1, "Counter should be 1");
        (batchIterator, batches, totalDemandAssets, totalPendingShares) = queue.getState();
        assertEq(batchIterator, 1, "Batch iterator should be 1");
        assertEq(batches, 2, "Batches length should be 2");
        assertEq(totalDemandAssets, 1 ether, "Total demand assets should be 1 ether");
        assertEq(totalPendingShares, 1 ether, "Total pending shares should be 1 ether");

        // Vault got more liquid assets, keep processing
        {
            vault.__setLiquidAssets(2 ether);
            counter = queue.handleBatches(1);

            assertEq(counter, 1, "Counter should be 1");
            (batchIterator, batches, totalDemandAssets, totalPendingShares) = queue.getState();
            assertEq(batchIterator, 2, "Batch iterator should be 2");
            assertEq(batches, 2, "Batches length should be 2");
            assertEq(totalDemandAssets, 0 ether, "Total demand assets should be 0 ether");
        }
    }

    // -----------------------------------------------------------------------
    // claim() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `claim` sends assets to the receiver.
    function testClaimSuccess() public {
        address receiver = makeAddr("receiver");

        vault.__setLiquidAssets(2 ether);
        vm.deal(address(queue), 2 ether);

        // First redeem request
        uint32 timestampFirstClaim = uint32(block.timestamp);
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        // Second redeem request
        uint32 timestampSecondClaim = uint32(block.timestamp);
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        queue.handleBatches(2);

        // Claim both requests
        uint32[] memory timestamps = new uint32[](2);
        timestamps[0] = timestampFirstClaim;
        timestamps[1] = timestampSecondClaim;
        vm.prank(user);
        uint256 assets = queue.claim(receiver, timestamps);
        assertEq(assets, 2 ether, "Assets should be 2 ether");

        // Check that the receiver received the assets
        assertEq(address(receiver).balance, 2 ether, "Receiver should have 2 ether");
    }

    /// @notice Tests that `claim` returns zero when there are no reports yet.
    function testClaimReturnsZero_NoReport() public {
        uint256 assets = queue.claim(user, new uint32[](0));
        assertEq(assets, 0, "Assets should be 0");
    }

    /// @notice Tests that `claim` returns zero when the caller has no request but reports exist.
    function testClaimReturnsZero_NoUserRequestButReportsExist() public {
        address otherUser = makeAddr("otherUser");
        _performRedeem(otherUser, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        (uint256 batchIterator, uint256 batches,,) = queue.getState();
        assertEq(batchIterator, 0, "Batch iterator should be 0");
        assertEq(batches, 1, "Batches length should be 1");

        uint256 assets = queue.claim(user, new uint32[](1));
        assertEq(assets, 0, "Assets should be 0");
    }

    /// @notice Tests that `claim` returns zero when caller's request is newer than the latest report.
    function testClaimReturnsZero_RequestNotIncludedInReport() public {
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        // First batch is handled so the request above is processed
        queue.handleBatches(1);

        // Make a NEW request; its timestamp > last report
        _performRedeem(user, 1 ether);
        skip(REDEEM_INTERVAL);

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(block.timestamp - REDEEM_INTERVAL);

        uint256 assets = queue.claim(user, timestamps);
        assertEq(assets, 0, "Assets should be 0");
    }

    /// @notice Tests that `claim` returns zero when the batch containing caller's request has not been handled yet.
    function testClaimReturnsZero_BatchNotHandled() public {
        _performRedeem(user, 1 ether);
        uint32 redeemTimestamp = uint32(block.timestamp);

        // Push a report that creates a batch but do NOT handle it
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        {
            (uint256 batchIterator,,,) = queue.getState();
            assertEq(batchIterator, 0, "Batch iterator should be 0 - batch not handled yet");
        }

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = redeemTimestamp;
        uint256 assets = queue.claim(user, timestamps);
        assertEq(assets, 0, "Assets should be 0 when batch is not yet handled");

        IRedeemQueue.Request[] memory requests = queue.requestsOf(user, 0, 1);
        assertEq(requests.length, 1, "Request should still be recorded for the user");
    }

    /// @notice Tests that the user claims asset by the price of the next report.
    function testClaimReturnsAssetByThePriceOfTheNextReport() public {
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        _performRedeem(user, 1 ether);

        uint32 requestTimestamp = uint32(block.timestamp);

        skip(REDEEM_INTERVAL);
        _pushReport(1e18 / 2);

        skip(REDEEM_INTERVAL);
        _pushReport(1e18 / 4);

        // Price is 1e18 / 2, so we need twice as much liquid assets to redeem 1 ether of shares
        vault.__setLiquidAssets(2 ether);
        vm.deal(address(queue), 2 ether);

        queue.handleBatches(2);

        uint32[] memory timestamps = new uint32[](1);
        timestamps[0] = uint32(requestTimestamp);

        vm.prank(user);
        uint256 assets = queue.claim(user, timestamps);

        assertEq(assets, 2 ether, "Wrong assets");
    }

    // -----------------------------------------------------------------------
    // canBeRemoved() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `canBeRemoved` returns true only after all requests have been handled.
    function testCanBeRemoved() public {
        // Case A: No requests were made
        // (?) We need to handle some deposits first
        assertEq(queue.canBeRemoved(), false, "Queue should not be removable");

        // Case B: Requests were made but not all have been handled
        _performRedeem(user, 1 ether);
        assertEq(queue.canBeRemoved(), false, "Queue should not be removable yet");

        // Case C: Got a report, but batch is not handled yet
        {
            skip(REDEEM_INTERVAL);
            _pushReport(1e18);
            assertEq(queue.canBeRemoved(), false, "Queue should be removable after all requests have been handled");
        }

        // Case D: Got a report, and batch is handled
        {
            vault.__setLiquidAssets(1 ether);
            queue.handleBatches(1);

            assertEq(queue.canBeRemoved(), true, "Queue should be removable after all requests have been handled");
        }
    }

    // -----------------------------------------------------------------------
    // Full redeem flow tests
    // -----------------------------------------------------------------------

    /// @notice Tests that multiple users can redeem their shares with the same report.
    function testFullRedeemFlow_MultipleUsers_SameReport() public {
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");
        address userC = makeAddr("userC");

        // User A, B, C each redeem 1 ether
        _performRedeem(userA, 1 ether);
        _performRedeem(userB, 1 ether);
        _performRedeem(userC, 1 ether);

        uint32 requestTimestamp = uint32(block.timestamp);

        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        // Check that all redeem requests are recorded into single batch
        {
            (, uint256 batches,,) = queue.getState();
            assertEq(batches, 1, "Batches length should be 1");

            (uint256 assets, uint256 shares) = queue.batchAt(0);
            assertEq(assets, 3 ether, "Total assets should be 3 ether");
            assertEq(shares, 3 ether, "Total shares should be 3 ether");
        }

        // Add liquid assets to the vault so that the batch can be processed
        vault.__setLiquidAssets(3 ether);

        // Process the batch
        queue.handleBatches(1);

        // Check that the batch is processed correctly
        {
            (uint256 batchIterator, uint256 batches,,) = queue.getState();
            assertEq(batchIterator, 1, "Batch iterator should be 1");
            assertEq(batches, 1, "Batches length should be 1");
        }

        // Claim the assets
        {
            vm.deal(address(queue), 3 ether);

            uint32[] memory timestamps = new uint32[](1);
            timestamps[0] = requestTimestamp;

            vm.prank(userA);
            uint256 assetsA = queue.claim(userA, timestamps);
            assertEq(assetsA, 1 ether, "Assets A should be 1 ether");

            vm.prank(userB);
            uint256 assetsB = queue.claim(userB, timestamps);
            assertEq(assetsB, 1 ether, "Assets B should be 1 ether");

            vm.prank(userC);
            uint256 assetsC = queue.claim(userC, timestamps);
            assertEq(assetsC, 1 ether, "Assets C should be 1 ether");
        }
    }

    /// @notice Tests that multiple users can redeem their shares with different reports.
    function testFullRedeemFlow_MultipleUsers_DifferentReports() public {
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");
        address userC = makeAddr("userC");

        // User A, B, C each redeem 1 ether
        _performRedeem(userA, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        _performRedeem(userB, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        _performRedeem(userC, 1 ether);
        skip(REDEEM_INTERVAL);
        _pushReport(1e18);

        uint32 requestTimestampA = uint32(block.timestamp - REDEEM_INTERVAL * 3);
        uint32 requestTimestampB = uint32(block.timestamp - REDEEM_INTERVAL * 2);
        uint32 requestTimestampC = uint32(block.timestamp - REDEEM_INTERVAL);

        // Check that all redeem requests are recorded into single batch
        {
            (, uint256 batches,,) = queue.getState();
            assertEq(batches, 3, "Batches length should be 3");

            for (uint256 i = 0; i < batches; i++) {
                (uint256 assets, uint256 shares) = queue.batchAt(i);
                assertEq(assets, 1 ether, "Total assets should be 1 ether");
                assertEq(shares, 1 ether, "Total shares should be 1 ether");
            }
        }

        // Add liquid assets to the vault so that all batches can be processed
        vault.__setLiquidAssets(3 ether);

        // Process the batches
        queue.handleBatches(3);

        // Check that the batch is processed correctly
        {
            (uint256 batchIterator, uint256 batches,,) = queue.getState();
            assertEq(batchIterator, 3, "Batch iterator should be 3");
            assertEq(batches, 3, "Batches length should be 3");
        }

        // Claim the assets
        {
            vm.deal(address(queue), 3 ether);

            uint32[] memory timestamps = new uint32[](3);

            timestamps[0] = requestTimestampA;
            vm.prank(userA);
            uint256 assetsA = queue.claim(userA, timestamps);
            assertEq(assetsA, 1 ether, "Assets A should be 1 ether");

            timestamps[0] = requestTimestampB;
            vm.prank(userB);
            uint256 assetsB = queue.claim(userB, timestamps);
            assertEq(assetsB, 1 ether, "Assets B should be 1 ether");

            timestamps[0] = requestTimestampC;
            vm.prank(userC);
            uint256 assetsC = queue.claim(userC, timestamps);
            assertEq(assetsC, 1 ether, "Assets C should be 1 ether");
        }
    }

    /// @notice Tests that multiple users can redeem their shares with different batches.
    function testFullRedeemFlow_MultipleUsers_DifferentBatches() public {
        uint256 users = 16;

        vault.__setLiquidAssets(1 ether * users);

        for (uint8 i = 0; i < users; i++) {
            user = vm.addr(i + 128);

            _performRedeem(user, 1 ether);
            skip(REDEEM_INTERVAL);
            _pushReport(1e18);

            // Check that all redeem requests are recorded into single batch
            {
                (, uint256 batches,,) = queue.getState();
                assertEq(batches, i + 1, "Wrong number of batches");

                (uint256 assets, uint256 shares) = queue.batchAt(i);
                assertEq(assets, 1 ether, string.concat("Wrong total assets in the batch: ", vm.toString(i)));
                assertEq(shares, 1 ether, string.concat("Wrong total shares in the batch: ", vm.toString(i)));
            }

            // Add liquid assets to the vault so that the batch can be processed

            // Process the batch
            queue.handleBatches(1);

            // Claim the assets
            {
                vm.deal(address(queue), 1 ether);

                uint32[] memory timestamps = new uint32[](1);
                timestamps[0] = uint32(block.timestamp - REDEEM_INTERVAL);

                vm.prank(user);
                uint256 assets = queue.claim(user, timestamps);
                assertEq(assets, 1 ether, "Assets should be 1 ether");
            }
        }

        // Check final state
        {
            (uint256 batchIterator, uint256 batches, uint256 totalDemandAssets, uint256 totalPendingShares) =
                queue.getState();
            assertEq(batchIterator, users, "Wrong batchIterator");
            assertEq(batches, users, "Wrong batches length");
            assertEq(totalDemandAssets, 0, "Wrong totalDemandAssets");
            assertEq(totalPendingShares, 0, "Wrong totalPendingShares");
        }
    }

    // -----------------------------------------------------------------------
    // Helper functions
    // -----------------------------------------------------------------------

    /// @notice Deploys a `RedeemQueue` behind a transparent proxy and initialises it.
    function _createQueue(address _asset, address _vault) internal returns (RedeemQueue) {
        RedeemQueue implementation = new RedeemQueue("MockRedeemQueue", 1);
        return RedeemQueue(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(implementation),
                        proxyAdmin,
                        abi.encodeWithSelector(RedeemQueue.initialize.selector, abi.encode(_asset, _vault, ""))
                    )
                )
            )
        );
    }

    /// @notice Reads raw storage at a specific slot and returns it as `uint256`.
    function _loadUintFromSlot(address _contract, bytes32 _slot) internal view returns (uint256 value) {
        bytes32 raw = vm.load(_contract, _slot);
        value = uint256(raw);
    }

    /// @notice Loads an address from a slot.
    function _loadAddressFromSlot(address _contract, bytes32 _slot) public view returns (address) {
        bytes32 rawAddress = vm.load(address(_contract), _slot);
        return address(uint160(uint256(rawAddress)));
    }

    /// @notice Performs a redeem on behalf of a given user.
    function _performRedeem(address _user, uint256 _shares) internal {
        vm.prank(_user);
        queue.redeem(_shares);
    }

    /// @notice Pushes a report to the queue.
    function _pushReport(uint224 _priceD18) internal {
        vm.prank(vaultAddress);
        queue.handleReport(_priceD18, uint32(block.timestamp - REDEEM_INTERVAL));
    }
}
