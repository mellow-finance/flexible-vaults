// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "../src/utils/PermissionedMinter.sol";

contract Integration is Test {
    function test() external {
        Vault vault = Vault(payable(0x807D4778abA870e4222904f5b528F68B350cE0E0));
        uint224 shares = 100 ether;
        address urd = makeAddr("urd");
        address admin = vault.getRoleMember(vault.DEFAULT_ADMIN_ROLE(), 0);
        (bytes32[] memory rolesBefore, address[][] memory holdersBefore) = vaultRolesAndHolders(vault);

        PermissionedMinter minter = new PermissionedMinter(vault, admin, urd, shares, 2);

        vm.startPrank(admin);

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(minter));
        minter.mint();
        console2.log(vault.shareManager().sharesOf(urd));

        for (uint256 roleIndex = 0; roleIndex < vault.supportedRoles(); roleIndex++) {
            bytes32 role = vault.supportedRoleAt(roleIndex);
            assertFalse(vault.hasRole(role, address(minter)), "minter should not have any role");
        }

        vm.stopPrank();

        (bytes32[] memory rolesAfter, address[][] memory holdersAfter) = vaultRolesAndHolders(vault);
        assertEq(rolesBefore.length, rolesAfter.length, "number of roles should not change");
        for (uint256 i = 0; i < rolesBefore.length; i++) {
            assertEq(rolesBefore[i], rolesAfter[i], "roles should not change");
            assertEq(holdersBefore[i].length, holdersAfter[i].length, "number of holders should not change");
            for (uint256 j = 0; j < holdersBefore[i].length; j++) {
                assertEq(holdersBefore[i][j], holdersAfter[i][j], "holders should not change");
            }
        }
    }

    function vaultRolesAndHolders(Vault vault)
        internal
        view
        returns (bytes32[] memory roles, address[][] memory holders)
    {
        uint256 roleCount = vault.supportedRoles();
        roles = new bytes32[](roleCount);
        holders = new address[][](roleCount);
        for (uint256 i = 0; i < roleCount; i++) {
            roles[i] = vault.supportedRoleAt(i);
            uint256 memberCount = vault.getRoleMemberCount(roles[i]);
            address[] memory roleHolders = new address[](memberCount);
            for (uint256 j = 0; j < memberCount; j++) {
                roleHolders[j] = vault.getRoleMember(roles[i], j);
            }
            holders[i] = roleHolders;
        }
    }
}
