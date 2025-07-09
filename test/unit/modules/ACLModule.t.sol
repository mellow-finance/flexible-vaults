// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract ACLModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address admin2 = vm.createWallet("admin2").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testFundamentalRole() external {
        MockACLModule acl = createACL("MockACLModule", 1, admin);

        vm.expectRevert("ZeroAddress()");
        acl.initialize(abi.encode(address(0)));

        assertFalse(acl.hasFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin));

        acl.initialize(abi.encode(admin));
        assertTrue(acl.hasFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin));

        vm.startPrank(admin);

        vm.expectRevert("ZeroAddress()");
        acl.grantFundamentalRole(IACLModule.FundamentalRole.ADMIN, address(0));

        vm.expectRevert("ZeroAddress()");
        acl.revokeFundamentalRole(IACLModule.FundamentalRole.ADMIN, address(0));

        acl.grantFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin2);
        assertTrue(acl.hasFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin2));

        acl.revokeFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin);
        assertFalse(acl.hasFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin));
    }

    function testRole() external {
        MockACLModule acl = createACL("MockACLModule", 1, admin);
        acl.initialize(abi.encode(admin));
        bytes32 role = acl.DEFAULT_ADMIN_ROLE();

        vm.expectRevert("Forbidden()");
        acl.requireFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin2);

        vm.prank(admin);
        vm.expectRevert("Forbidden()");
        acl.grantRole(role, admin2);

        vm.prank(admin);
        acl.grantFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin2);
        assertTrue(acl.hasFundamentalRole(IACLModule.FundamentalRole.ADMIN, admin2));

        vm.prank(admin);
        acl.grantRole(role, admin2);
    }

    function createACL(string memory name, uint256 version, address admin) internal returns (MockACLModule acl) {
        MockACLModule aclImplementation = new MockACLModule(name, version);
        acl = MockACLModule(
            payable(new TransparentUpgradeableProxy(address(aclImplementation), proxyAdmin, new bytes(0)))
        );
    }
}
