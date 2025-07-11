// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockQueue is Queue {
    constructor(string memory name_, uint256 version_) Queue(name_, version_) {}

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        __ReentrancyGuard_init();
        (address asset_, address vault_) = abi.decode(data, (address, address));
        __Queue_init(asset_, vault_);
    }

    function timestamps() external view returns (Checkpoints.Trace224 memory) {
        return _timestamps();
    }

    function canBeRemoved() external pure returns (bool) {
        return false;
    }

    function _handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) internal override {}

    function test() external {}
}

contract QueueTest is Test {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address asset = vm.createWallet("asset").addr;
    address vault = vm.createWallet("vault").addr;

    function testCreate() external {
        MockQueue queue = createQueue();

        assertEq(queue.timestamps()._checkpoints.length, 0, "Initial timestamps length should be zero");

        assertEq(queue.vault(), address(0), "Vault address should be zero");
        assertEq(queue.asset(), address(0), "Asset address should be zero");

        vm.expectRevert(abi.encodeWithSelector(IQueue.ZeroValue.selector));
        queue.initialize(abi.encode(address(0), vault));

        vm.expectRevert(abi.encodeWithSelector(IQueue.ZeroValue.selector));
        queue.initialize(abi.encode(asset, address(0)));

        queue.initialize(abi.encode(asset, vault));

        assertEq(queue.vault(), vault, "Vault address mismatch");
        assertEq(queue.asset(), asset, "Asset address mismatch");
        assertEq(queue.timestamps()._checkpoints.length, 1, "Initial timestamps length should be 1");
        assertEq(queue.timestamps()._checkpoints[0]._key, block.timestamp, "Initial timestamps mismatch");
        assertEq(queue.timestamps()._checkpoints[0]._value, 0, "Initial checkpoint value mismatch");

        queue.timestamps();
    }

    function testHandleReport() external {
        MockQueue queue = createQueue();
        queue.initialize(abi.encode(asset, vault));

        vm.expectRevert(abi.encodeWithSelector(IQueue.Forbidden.selector));
        queue.handleReport(1 ether, uint32(block.timestamp - 1 hours));

        vm.startPrank(vault);

        vm.expectRevert(abi.encodeWithSelector(IQueue.InvalidReport.selector));
        queue.handleReport(0, uint32(block.timestamp - 1 hours));

        vm.expectRevert(abi.encodeWithSelector(IQueue.InvalidReport.selector));
        queue.handleReport(1 ether, uint32(block.timestamp));

        vm.stopPrank();
    }

    function createQueue() internal returns (MockQueue queue) {
        MockQueue queueImplementation = new MockQueue("MockQueue", 0);
        queue = MockQueue(
            payable(new TransparentUpgradeableProxy(address(queueImplementation), vaultProxyAdmin, new bytes(0)))
        );
    }
}
