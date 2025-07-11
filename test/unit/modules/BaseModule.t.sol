// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockBaseModule is BaseModule {
    function initialize(bytes calldata) external initializer {
        __BaseModule_init();
    }

    function test() external {}
}

contract BaseModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address admin2 = vm.createWallet("admin2").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testCreate() external {
        MockBaseModule module = createBaseModule();
        require(address(module) != address(0), "Module creation failed");
    }

    function testGetStorageAt() external {
        MockBaseModule module = createBaseModule();
        module.getStorageAt(0);
    }

    function testOnERC721Received() external {
        MockBaseModule module = createBaseModule();
        assertEq(
            module.onERC721Received(address(0), address(0), 0, new bytes(0)), IERC721Receiver.onERC721Received.selector
        );
    }

    function createBaseModule() internal returns (MockBaseModule module) {
        MockBaseModule moduleImplementation = new MockBaseModule();
        module = MockBaseModule(
            payable(new TransparentUpgradeableProxy(address(moduleImplementation), proxyAdmin, new bytes(0)))
        );
        module.initialize(abi.encode(""));
    }
}
