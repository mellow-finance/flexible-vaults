// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract DepositQueueTest2 is Test {
    address internal proxyAdmin = makeAddr("proxyAdmin");

    MockVault internal vault;

    address internal user;

    address internal assetAddress;
    address internal vaultAddress;

    DepositQueue internal queue;

    uint32 constant DEPOSIT_INTERVAL = 1 hours;

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
        string memory name = "MockDepositQueue";

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

    /// @notice Tests that derived storage slot for the `DepositQueue` is unique
    function testConstructorSetsUniqueStorageSlotsForDepositQueue() public {
        uint256 version = 1;
        string memory moduleName = "DepositQueue";
        string memory name = "MockDepositQueue";

        // Set `handledIndices` to 1
        {
            _performDeposit(user, 1 ether);
            skip(DEPOSIT_INTERVAL);
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

    // -----------------------------------------------------------------------
    // requestOf() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `requestOf` returns zeroes for a user with no pending request.
    function testRequestOfReturnsEmptyForNewUser() public view {
        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, 0);
        assertEq(assets, 0);
    }

    /// @notice Tests that `requestOf` returns correct values for a user with a pending request.
    function testRequestOfReturnsCorrectValuesForPendingRequest() public {
        _performDeposit(user, 1 ether);
        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, block.timestamp);
        assertEq(assets, 1 ether);
    }

    // -----------------------------------------------------------------------
    // claimableOf() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `claimableOf` returns zero if user didn't deposit.
    function testClaimableOfReturnsZeroWithoutDeposit() public view {
        assertEq(queue.claimableOf(user), 0);
    }

    /// @notice Tests that `claimableOf` returns zero if user's deposit wasn't processed yet.
    function testClaimableOfReturnsZeroWithoutProcessing() public {
        _performDeposit(user, 1 ether);
        assertEq(queue.claimableOf(user), 0);
    }

    /// @notice Tests that `claimableOf` returns correct values for a user with processed deposit.
    function testClaimableOfReturnsCorrectValuesForProcessedDeposit() public {
        _performDeposit(user, 1 ether);
        skip(DEPOSIT_INTERVAL);
        _pushReport(1e18);
        assertEq(queue.claimableOf(user), 1 ether);
    }

    // -----------------------------------------------------------------------
    // deposit() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `deposit` reverts when `assets` is zero.
    function testDepositRevertsOnZeroAssets() public {
        vm.expectRevert(IQueue.ZeroValue.selector);
        queue.deposit(0, address(0), new bytes32[](0));
    }

    /// @notice Tests that `deposit` reverts when the queue is paused.
    function testDepositRevertsWhenQueuePaused() public {
        vault.__setPausedQueue(address(queue));
        vm.expectRevert(IQueue.QueuePaused.selector);
        queue.deposit(1 ether, address(0), new bytes32[](0));
    }

    /// @notice Tests that `deposit` reverts when the caller is not allowed to deposit (whitelist check fails).
    function testDepositRevertsWhenDepositNotAllowed() public {
        MockShareManager shareManager = vault.addShareManager();
        shareManager.__setWhitelistEnabled(true);

        vm.expectRevert(IDepositQueue.DepositNotAllowed.selector);
        queue.deposit(1 ether, address(0), new bytes32[](0));
    }

    /// @notice Tests that `deposit` reverts when a non-claimable pending request already exists for the caller.
    function testDepositRevertsWhenPendingRequestExists() public {
        _performDeposit(user, 1 ether);
        vm.expectRevert(IDepositQueue.PendingRequestExists.selector);
        _performDeposit(user, 1 ether);
    }

    /// @notice Tests that a successful `deposit` records the request and modifies the pending assets.
    function testDepositSuccess(uint224 amount) public {
        vm.assume(amount > 0);

        // Check that the pending assets are modified
        vm.expectCall(
            address(vault.riskManager()),
            abi.encodeWithSelector(MockRiskManager.modifyPendingAssets.selector, assetAddress, int256(uint256(amount)))
        );

        // Create a pending request
        _performDeposit(user, amount);

        // Check that the request is recorded
        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, block.timestamp);
        assertEq(assets, uint256(amount));
    }

    // -----------------------------------------------------------------------
    // cancelDepositRequest() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `cancelDepositRequest` successfully refunds assets before the request becomes claimable.
    function testCancelDepositRequestSuccess() public {
        uint256 balanceBefore = _performDeposit(user, 1 ether);

        // Check that the balance is modified
        uint256 balanceAfter = address(user).balance;
        assertEq(balanceAfter, balanceBefore - 1 ether);

        // Check that the deposit is not claimable
        assertEq(queue.claim(user), false, "Deposit should not be claimable yet");

        // Check that the pending assets are modified
        vm.expectCall(
            address(vault.riskManager()),
            abi.encodeWithSelector(
                MockRiskManager.modifyPendingAssets.selector, assetAddress, -int256(uint256(1 ether))
            )
        );

        vm.expectEmit(true, true, true, true);
        emit IDepositQueue.DepositRequestCanceled(user, 1 ether, uint32(block.timestamp));

        // Cancel the request
        _cancelDepositRequest(user);

        // Check that the balance is the same as before the deposit
        uint256 balanceAfterCancel = address(user).balance;
        assertEq(balanceAfterCancel, balanceBefore);

        // Check that the request is cancelled
        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, 0);
        assertEq(assets, 0);
    }

    /// @notice Tests that `cancelDepositRequest` reverts if no pending request exists.
    function testCancelDepositRequestRevertsOnNoPendingRequest() public {
        // Case A: No request was made
        vm.expectRevert(IDepositQueue.NoPendingRequest.selector);
        _cancelDepositRequest(user);

        // Case B: Request is already processed and claimed
        {
            _performDeposit(user, 1 ether);
            skip(DEPOSIT_INTERVAL);
            _pushReport(1e18);
            queue.claim(user);
        }
        vm.expectRevert(IDepositQueue.NoPendingRequest.selector);
        _cancelDepositRequest(user);
    }

    /// @notice Tests that `cancelDepositRequest` reverts once the request is already claimable.
    function testCancelDepositRequestRevertsOnClaimable() public {
        // Deposit and process the request
        {
            _performDeposit(user, 1 ether);
            skip(DEPOSIT_INTERVAL);
            _pushReport(1e18);
        }

        // Request is already processed and not claimed
        vm.expectRevert(IDepositQueue.ClaimableRequestExists.selector);
        _cancelDepositRequest(user);
    }

    // -----------------------------------------------------------------------
    // claim() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `claim` returns false when the request is not yet claimable.
    function testClaimReturnsFalseIfNotClaimable() public {
        // Case A: No request was made
        assertEq(queue.claim(user), false, "There should be no pending request");

        // Case B: Request is not processed yet
        _performDeposit(user, 1 ether);
        assertEq(queue.claim(user), false, "Deposit should not be claimable yet");
    }

    /// @notice Tests that `claim` successfully mints allocated shares after a valid price report.
    function testClaimSuccess() public {
        // Deposit and process the request
        {
            _performDeposit(user, 1 ether);
            skip(DEPOSIT_INTERVAL);
            _pushReport(1e18);
        }

        // Check that the shares are minted
        vm.expectCall(
            address(vault.shareManager()),
            abi.encodeWithSelector(MockShareManager.mintAllocatedShares.selector, user, 1 ether)
        );

        assertEq(queue.claim(user), true, "Deposit should be claimable now");

        // Check if request is deleted
        (uint256 timestamp, uint256 assets) = queue.requestOf(user);
        assertEq(timestamp, 0);
        assertEq(assets, 0);
    }

    // -----------------------------------------------------------------------
    // handleReport() internal hook tests (invoked via public `handleReport` in Queue)
    // -----------------------------------------------------------------------

    /// @notice Tests that `handleReport` processes eligible requests, allocates shares and call the hook.
    function testHandleReportProcessesValidBatch() public {
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");

        _performDeposit(userA, 1 ether);
        _performDeposit(userB, 2 ether);

        skip(DEPOSIT_INTERVAL);

        // Check that the pending assets are modified
        vm.expectCall(
            address(vault.riskManager()),
            abi.encodeWithSelector(MockRiskManager.modifyPendingAssets.selector, assetAddress, -3 ether)
        );

        // Check that the vault balance is modified
        vm.expectCall(
            address(vault.riskManager()),
            abi.encodeWithSelector(MockRiskManager.modifyVaultBalance.selector, assetAddress, 3 ether)
        );

        // Check that the deposit hook is called
        vm.expectEmit(true, true, true, true);
        emit MockVault.__HookCalled(3 ether);

        // Check that the correct amount of shares is allocated
        vm.expectCall(
            address(vault.shareManager()), abi.encodeWithSelector(MockShareManager.allocateShares.selector, 3 ether)
        );

        uint256 balanceBefore = address(vault).balance;

        _pushReport(1e18);

        // Check that vault balance is actually got all the assets
        assertEq(address(vault).balance - balanceBefore, 3 ether);
    }

    /// @notice Tests that `handleReport` early-exits when no requests are eligible.
    function testHandleReportSkipsWhenNoEligibleRequests() public {
        // Case A: No requests were made
        {
            uint256 balanceBefore = address(vault).balance;
            _pushReport(1e18);
            assertEq(address(vault).balance, balanceBefore);
        }

        // Case B: No requests are eligible
        {
            uint256 balanceBefore = address(vault).balance;
            _performDeposit(user, 1 ether);
            _pushReport(1e18);
            assertEq(address(vault).balance, balanceBefore);
        }
    }

    /// @notice Tests that `handleReport` correctly handles the fees.
    function testHandleReportCorrectlyHandlesFees() public {
        address feeRecipient = makeAddr("feeRecipient");

        MockFeeManager feeManager = vault.addFeeManager();
        feeManager.__setDepositFeeInPercentage(10);
        feeManager.__setFeeRecipient(feeRecipient);

        _performDeposit(user, 1 ether);

        skip(DEPOSIT_INTERVAL);

        // Check that the correct amount of shares is allocated and fees are minted
        {
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.allocateShares.selector, 0.9 ether)
            );
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.mint.selector, feeRecipient, 0.1 ether)
            );
            _pushReport(1e18);
        }

        // Check that the user can get his shares
        {
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.mintAllocatedShares.selector, user, 0.9 ether)
            );
            queue.claim(user);
        }
    }

    /// Tests that `handleReport` correctly handles the fees with multiple depositors.
    function testHandleReportCorrectlyHandlesFeesWithMultipleDepositors() public {
        address feeRecipient = makeAddr("feeRecipient");

        MockFeeManager feeManager = vault.addFeeManager();
        feeManager.__setDepositFeeInPercentage(10);
        feeManager.__setFeeRecipient(feeRecipient);

        address userA = makeAddr("userA");
        address userB = makeAddr("userB");

        _performDeposit(userA, 2 ether);
        _performDeposit(userB, 2 ether);

        skip(DEPOSIT_INTERVAL);

        // Check that the correct amount of shares is allocated and fees are minted
        {
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.allocateShares.selector, 3.6 ether)
            );
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.mint.selector, feeRecipient, 0.4 ether)
            );
            _pushReport(1e18);
        }

        // Check that the user can get his shares
        {
            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.mintAllocatedShares.selector, userA, 1.8 ether)
            );
            queue.claim(userA);

            vm.expectCall(
                address(vault.shareManager()),
                abi.encodeWithSelector(MockShareManager.mintAllocatedShares.selector, userB, 1.8 ether)
            );
            queue.claim(userB);
        }
    }

    /// @notice Tests that `handleReport` correctly handles multiple deposits with `interval` between requests.
    function testHandleReportCorrectlyHandlesMultipleDeposits(uint32 interval, uint32 reportDelay) public {
        vm.assume(interval >= DEPOSIT_INTERVAL && interval < 10 * 365 days);
        vm.assume(reportDelay < DEPOSIT_INTERVAL);

        address userA = makeAddr("userA");
        address userB = makeAddr("userB");

        skip(1);

        _performDeposit(userA, 1 ether);

        skip(interval);

        _performDeposit(userB, 2 ether);

        skip(reportDelay);

        _pushReport(1e18);

        // Check that only the first deposit is processed
        assertEq(queue.claim(userA), true, "Deposit should be claimable");
        assertEq(queue.claim(userB), false, "Deposit should not be claimable");
    }

    // -----------------------------------------------------------------------
    // canBeRemoved() function tests
    // -----------------------------------------------------------------------

    /// @notice Tests that `canBeRemoved` returns true only after all timestamps have been handled.
    function testCanBeRemoved() public {
        // Case A: No requests were made
        // (?) We need to handle some deposits first
        assertEq(queue.canBeRemoved(), false, "Queue should not be removable");

        // Case B: Requests were made but not all have been handled
        _performDeposit(user, 1 ether);
        assertEq(queue.canBeRemoved(), false, "Queue should not be removable yet");

        // Case C: All requests have been handled
        {
            skip(DEPOSIT_INTERVAL);
            _pushReport(1e18);
            assertEq(queue.canBeRemoved(), true, "Queue should be removable after all requests have been handled");
        }
    }

    // -----------------------------------------------------------------------
    // Helper functions
    // -----------------------------------------------------------------------

    /// @notice Deploys a `DepositQueue` behind a transparent proxy and initialises it.
    function _createQueue(address _asset, address _vault) internal returns (DepositQueue) {
        DepositQueue implementation = new DepositQueue("MockDepositQueue", 1);
        return DepositQueue(
            address(
                new TransparentUpgradeableProxy(
                    address(implementation),
                    proxyAdmin,
                    abi.encodeWithSelector(DepositQueue.initialize.selector, abi.encode(_asset, _vault, ""))
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

    /// @notice Performs a deposit on behalf of a given user.
    function _performDeposit(address _user, uint224 _amount) internal returns (uint256 balanceBefore) {
        vm.deal(_user, _amount);
        vm.prank(_user);

        balanceBefore = address(_user).balance;

        queue.deposit{value: _amount}(_amount, address(0), new bytes32[](0));
    }

    /// @notice Cancels a deposit request on behalf of a given user.
    function _cancelDepositRequest(address _user) internal {
        vm.prank(_user);
        queue.cancelDepositRequest();
    }

    /// @notice Pushes a report to the queue.
    function _pushReport(uint224 _priceD18) internal {
        vm.prank(vaultAddress);
        queue.handleReport(_priceD18, uint32(block.timestamp - DEPOSIT_INTERVAL));
    }
}
