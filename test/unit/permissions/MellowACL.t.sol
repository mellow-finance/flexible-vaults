// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockMellowACL is MellowACL {
    bytes32 public constant ROLE_NUMBER_ONE = keccak256("permissions.MockMellowACL.ROLE_NUMBER_ONE");
    bytes32 public constant ROLE_NUMBER_TWO = keccak256("permissions.MockMellowACL.ROLE_NUMBER_TWO");
    bytes32 public constant ROLE_ONLY_SELF_OR_ROLE = keccak256("permissions.MockMellowACL.ROLE_ONLY_SELF_OR_ROLE");

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    function initialize(bytes calldata data) external initializer {
        (address admin_) = abi.decode(data, (address));
        if (admin_ == address(0)) {
            revert();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    // function mockOnlySelfOrRoleWrap() external {
    //     mockOnlySelfOrRole();
    // }

    // function mockOnlySelfOrRole() public onlySelfOrRole(ROLE_ONLY_SELF_OR_ROLE) {}

    function test() external {}
}

contract MellowACLTest is Test {
    address ROLE_NUMBER_ONE_ADDRESS = vm.createWallet("ROLE_NUMBER_ONE").addr;
    address ROLE_NUMBER_TWO_ADDRESS = vm.createWallet("ROLE_NUMBER_TWO").addr;
    address ROLE_ONLY_SELF_OR_ROLE_ADDRESS = vm.createWallet("ROLE_ONLY_SELF_OR_ROLE").addr;

    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    function testInitialize() external {
        MockMellowACL acl = createMellowACL("MockMellowACL", 1, admin);

        assertEq(acl.supportedRoles(), 1);
        assertEq(acl.supportedRoleAt(0), acl.DEFAULT_ADMIN_ROLE());
        assertTrue(acl.hasSupportedRole(acl.DEFAULT_ADMIN_ROLE()));
    }

    function testOnlySelfOrRole() external {
        MockMellowACL acl = createMellowACL("MockMellowACL", 1, admin);
        bytes32 role = acl.ROLE_ONLY_SELF_OR_ROLE();

        vm.prank(admin);
        acl.grantRole(role, ROLE_ONLY_SELF_OR_ROLE_ADDRESS);

        // vm.expectRevert(
        //     abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), role)
        // );
        // acl.mockOnlySelfOrRole();

        // vm.prank(ROLE_ONLY_SELF_OR_ROLE_ADDRESS);
        // acl.mockOnlySelfOrRole();
    }

    function testGrantRole() external {
        bytes32 role;
        MockMellowACL acl = createMellowACL("MockMellowACL", 1, admin);

        bytes32 defaultAdminRole = acl.DEFAULT_ADMIN_ROLE();
        role = acl.ROLE_NUMBER_ONE();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), defaultAdminRole
            )
        );
        acl.grantRole(role, ROLE_NUMBER_ONE_ADDRESS);

        vm.prank(admin);
        acl.grantRole(role, ROLE_NUMBER_ONE_ADDRESS);
        assertEq(acl.supportedRoles(), 2);

        assertEq(acl.supportedRoleAt(1), acl.ROLE_NUMBER_ONE());
        assertTrue(acl.hasSupportedRole(acl.ROLE_NUMBER_ONE()));

        role = acl.ROLE_NUMBER_TWO();
        vm.prank(admin);
        acl.grantRole(role, ROLE_NUMBER_TWO_ADDRESS);
        assertEq(acl.supportedRoles(), 3);

        assertEq(acl.supportedRoleAt(2), acl.ROLE_NUMBER_TWO());
        assertTrue(acl.hasSupportedRole(acl.ROLE_NUMBER_TWO()));
    }

    function testRevokeRole() external {
        MockMellowACL acl = createMellowACL("MockMellowACL", 1, admin);

        vm.startPrank(admin);
        acl.grantRole(acl.ROLE_NUMBER_ONE(), ROLE_NUMBER_ONE_ADDRESS);
        assertEq(acl.getRoleMemberCount(acl.ROLE_NUMBER_ONE()), 1);

        acl.grantRole(acl.ROLE_NUMBER_ONE(), ROLE_NUMBER_TWO_ADDRESS);
        assertEq(acl.getRoleMemberCount(acl.ROLE_NUMBER_ONE()), 2);

        assertEq(acl.supportedRoles(), 2);

        acl.revokeRole(acl.ROLE_NUMBER_TWO(), ROLE_NUMBER_ONE_ADDRESS);

        acl.revokeRole(acl.ROLE_NUMBER_ONE(), ROLE_NUMBER_ONE_ADDRESS);
        assertEq(acl.supportedRoles(), 2);
        assertEq(acl.getRoleMemberCount(acl.ROLE_NUMBER_ONE()), 1);

        acl.revokeRole(acl.ROLE_NUMBER_ONE(), ROLE_NUMBER_TWO_ADDRESS);
        assertEq(acl.supportedRoles(), 1);
    }

    function createMellowACL(string memory name, uint256 version, address admin_)
        internal
        returns (MockMellowACL acl)
    {
        MockMellowACL aclImplementation = new MockMellowACL(name, version);
        acl = MockMellowACL(
            address(new TransparentUpgradeableProxy(address(aclImplementation), proxyAdmin, new bytes(0)))
        );
        acl.initialize(abi.encode(admin_));
    }
}
