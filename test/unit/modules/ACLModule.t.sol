// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract ACLModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address admin2 = vm.createWallet("admin2").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testRole() external {
        MockACLModule acl = createACL("MockACLModule", 1);
        acl.initialize(abi.encode(admin));
        bytes32 role = acl.DEFAULT_ADMIN_ROLE();
        vm.prank(admin);
        acl.grantRole(role, admin2);
        vm.prank(admin);
        acl.grantRole(role, admin2);
    }

    function createACL(string memory name, uint256 version) internal returns (MockACLModule acl) {
        MockACLModule aclImplementation = new MockACLModule(name, version);
        acl = MockACLModule(
            payable(new TransparentUpgradeableProxy(address(aclImplementation), proxyAdmin, new bytes(0)))
        );
    }
}
