// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

import {MockQueue} from "./Queue.t.sol";

contract QueueTest2 is Test {
    address internal asset = makeAddr("asset");
    address internal vault = makeAddr("vault");
    address internal proxyAdmin = makeAddr("proxyAdmin");

    MockQueue internal queue;

    function setUp() public {
        queue = _createQueue(asset, vault);
    }

    /**
     * Constructor tests
     */
    function testConstructorSetsUniqueStorageSlot() public view {
        uint256 version = 1;
        string memory moduleName = "Queue";
        string memory name = "MockQueue";

        // Ensure the storage slot is set correctly
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedAsset = _loadAddressFromSlot(address(queue), moduleSlot);
            assertEq(storedAsset, asset, "Asset address mismatch");
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

    /**
     * Initialize function tests
     */

    /// @notice Tests that `initialize` correctly sets the asset, vault and pushes the initial timestamp.
    function testInitializeSetsStateCorrectly() public view {
        assertEq(queue.vault(), vault, "vault mismatch");
        assertEq(queue.asset(), asset, "asset mismatch");

        assertEq(queue.timestamps()._checkpoints.length, 1, "No timestamps after init");
        assertEq(queue.timestamps()._checkpoints[0]._key, block.timestamp, "Timestamp mismatch");
        assertEq(queue.timestamps()._checkpoints[0]._value, 0, "Initial value should be zero");
    }

    /// @notice Tests that `initialize` reverts when called with a zero asset address.
    function testInitializeRevertsOnZeroAsset() public {
        MockQueue implementation = new MockQueue("MockQueue", 1);

        vm.expectRevert(IQueue.ZeroValue.selector);
        new TransparentUpgradeableProxy(
            address(implementation),
            proxyAdmin,
            abi.encodeWithSelector(MockQueue.initialize.selector, abi.encode(address(0), vault))
        );
    }

    /// @notice Tests that `initialize` reverts when called with a zero vault address.
    function testInitializeRevertsOnZeroVault() public {
        MockQueue implementation = new MockQueue("MockQueue", 1);

        vm.expectRevert(IQueue.ZeroValue.selector);
        new TransparentUpgradeableProxy(
            address(implementation),
            proxyAdmin,
            abi.encodeWithSelector(MockQueue.initialize.selector, abi.encode(asset, address(0)))
        );
    }

    /// @notice Tests that `initialize` can only be executed once.
    function testInitializeRevertsIfCalledTwice() public {
        vm.expectRevert();
        queue.initialize(abi.encode(asset, vault));
    }

    /**
     * View functions
     */

    /// @notice Tests that `vault()` returns expected value after initialization.
    function testVaultReturnExpectedValue(uint160 addressBytes) public {
        vm.assume(addressBytes > 0);
        address _vault = address(addressBytes);
        assertEq(_createQueue(asset, _vault).vault(), _vault, "vault mismatch");
    }

    /// @notice Tests that `asset()` returns expected value after initialization.
    function testAssetReturnExpectedValue(uint160 addressBytes) public {
        vm.assume(addressBytes > 0);
        address _asset = address(addressBytes);
        assertEq(_createQueue(_asset, vault).asset(), _asset, "asset mismatch");
    }

    /**
     * handleReport function tests
     */

    /// @notice Tests that `handleReport` successfully processes a valid report, emits an event
    function testHandleReportSuccess(uint224 priceD18, uint32 timestamp) public {
        vm.assume(priceD18 > 0);
        vm.assume(timestamp < block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit IQueue.ReportHandled(priceD18, timestamp);

        vm.prank(vault);
        queue.handleReport(priceD18, timestamp);
    }

    /// @notice Tests that `handleReport` calls the internal hook.
    function testHandleReportCallsInternalHook(uint224 priceD18, uint32 timestamp) public {
        vm.assume(priceD18 > 0);
        vm.assume(timestamp < block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit MockQueue.ReportHookCalled(priceD18, timestamp);

        vm.prank(vault);
        queue.handleReport(priceD18, timestamp);
    }

    /// @notice Tests that `handleReport` reverts when invoked by an address other than the vault.
    function testHandleReportRevertsForNonVaultCaller() public {
        vm.expectRevert(IQueue.Forbidden.selector);
        queue.handleReport(1e18, uint32(block.timestamp - 1 hours));
    }

    /// @notice Tests that `handleReport` reverts when the provided price is zero.
    function testHandleReportRevertsOnZeroPrice() public {
        vm.expectRevert(IQueue.InvalidReport.selector);
        vm.prank(vault);
        queue.handleReport(0, uint32(block.timestamp - 1 hours));
    }

    /// @notice Tests that `handleReport` reverts when the report timestamp is in the future (>= block.timestamp).
    function testHandleReportRevertsOnFutureTimestamp() public {
        vm.expectRevert(IQueue.InvalidReport.selector);
        vm.prank(vault);
        queue.handleReport(1e18, uint32(block.timestamp));

        vm.expectRevert(IQueue.InvalidReport.selector);
        vm.prank(vault);
        queue.handleReport(1e18, uint32(block.timestamp + 1 hours));
    }

    /**
     * Helper functions
     */

    /// @notice Creates and initializes a queue.
    function _createQueue(address _asset, address _vault) internal returns (MockQueue) {
        MockQueue implementation = new MockQueue("MockQueue", 1);
        return MockQueue(
            address(
                new TransparentUpgradeableProxy(
                    address(implementation),
                    proxyAdmin,
                    abi.encodeWithSelector(MockQueue.initialize.selector, abi.encode(_asset, _vault))
                )
            )
        );
    }

    /// @notice Loads an address from a slot.
    function _loadAddressFromSlot(address _contract, bytes32 _slot) public view returns (address) {
        bytes32 rawAddress = vm.load(address(_contract), _slot);
        return address(uint160(uint256(rawAddress)));
    }
}
