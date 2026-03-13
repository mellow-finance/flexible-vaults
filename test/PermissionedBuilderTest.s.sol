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

        PermissionedMinter minter = new PermissionedMinter(vault, admin, urd, shares, 2);

        vm.startPrank(admin);

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(minter));
        minter.mint();
        console2.log(vault.shareManager().sharesOf(urd));

        vm.stopPrank();
    }
}
