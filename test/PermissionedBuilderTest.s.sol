// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "../src/utils/PermissionedMinter.sol";

struct VaultState {
    uint256 queueLimit;
    int256 vaultLimit;
    address[] assets;
    address[] queue;
    bytes32[] roles;
    address[][] roleHolders;
    IOracle.DetailedReport[] oracleReports;
}

contract Integration is Test {
    function test() external {
        Vault vault = Vault(payable(0x807D4778abA870e4222904f5b528F68B350cE0E0));
        uint224 shares = 100 ether;
        address urd = makeAddr("urd");
        address admin = vault.getRoleMember(vault.DEFAULT_ADMIN_ROLE(), 0);
        VaultState memory stateBefore = getVaultState(vault);

        PermissionedMinter minter = new PermissionedMinter(vault, admin, urd, shares, 3);

        vm.startPrank(admin);

        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(minter));
        minter.mint();
        console2.log(vault.shareManager().sharesOf(urd));

        for (uint256 roleIndex = 0; roleIndex < vault.supportedRoles(); roleIndex++) {
            bytes32 role = vault.supportedRoleAt(roleIndex);
            assertFalse(vault.hasRole(role, address(minter)), "minter should not have any role");
        }

        vm.stopPrank();

        VaultState memory stateAfter = getVaultState(vault);

        compareVaultStates(stateBefore, stateAfter);
    }

    function getVaultState(Vault vault) internal view returns (VaultState memory state) {
        uint256 roleCount = vault.supportedRoles();
        state.roles = new bytes32[](roleCount);
        state.roleHolders = new address[][](roleCount);
        for (uint256 i = 0; i < roleCount; i++) {
            state.roles[i] = vault.supportedRoleAt(i);
            uint256 memberCount = vault.getRoleMemberCount(state.roles[i]);
            address[] memory roleHolders = new address[](memberCount);
            for (uint256 j = 0; j < memberCount; j++) {
                roleHolders[j] = vault.getRoleMember(state.roles[i], j);
            }
            state.roleHolders[i] = roleHolders;
        }
        state.queueLimit = vault.queueLimit();
        state.vaultLimit = vault.riskManager().vaultState().limit;

        state.queue = new address[](vault.getQueueCount());
        state.assets = new address[](vault.getAssetCount());
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            state.assets[i] = vault.assetAt(i);
            for (uint256 j = 0; j < vault.getQueueCount(state.assets[i]); j++) {
                state.queue[i] = vault.queueAt(state.assets[i], j);
            }
        }
        IOracle oracle = IOracle(vault.oracle());
        state.oracleReports = new IOracle.DetailedReport[](state.assets.length);
        for (uint256 i = 0; i < state.assets.length; i++) {
            state.oracleReports[i] = oracle.getReport(state.assets[i]);
        }
    }

    function compareVaultStates(VaultState memory stateBefore, VaultState memory stateAfter) internal pure {
        assertEq(stateBefore.queueLimit, stateAfter.queueLimit, "queue limit should not change");
        assertEq(stateBefore.vaultLimit, stateAfter.vaultLimit, "vault limit should not change");
        assertEq(stateBefore.assets.length, stateAfter.assets.length, "number of assets should not change");
        for (uint256 i = 0; i < stateBefore.assets.length; i++) {
            assertEq(stateBefore.assets[i], stateAfter.assets[i], "assets should not change");
        }
        assertEq(stateBefore.queue.length, stateAfter.queue.length, "number of queue entries should not change");
        for (uint256 i = 0; i < stateBefore.queue.length; i++) {
            assertEq(stateBefore.queue[i], stateAfter.queue[i], "queue entries should not change");
        }
        assertEq(stateBefore.roles.length, stateAfter.roles.length, "number of roles should not change");
        for (uint256 i = 0; i < stateBefore.roles.length; i++) {
            assertEq(stateBefore.roles[i], stateAfter.roles[i], "roles should not change");
            assertEq(
                stateBefore.roleHolders[i].length,
                stateAfter.roleHolders[i].length,
                "number of role holders should not change"
            );
            for (uint256 j = 0; j < stateBefore.roleHolders[i].length; j++) {
                assertEq(stateBefore.roleHolders[i][j], stateAfter.roleHolders[i][j], "role holders should not change");
            }
        }
        assertEq(
            stateBefore.oracleReports.length,
            stateAfter.oracleReports.length,
            "number of oracle reports should not change"
        );
        for (uint256 i = 0; i < stateBefore.oracleReports.length; i++) {
            assertEq(
                stateBefore.oracleReports[i].priceD18,
                stateAfter.oracleReports[i].priceD18,
                "oracle report prices should not change"
            );
            assertEq(
                stateBefore.oracleReports[i].timestamp,
                stateAfter.oracleReports[i].timestamp,
                "oracle report timestamps should not change"
            );
            assertEq(
                stateBefore.oracleReports[i].isSuspicious,
                stateAfter.oracleReports[i].isSuspicious,
                "oracle report suspicious flags should not change"
            );
        }
    }
}
