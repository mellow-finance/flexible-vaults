// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract ShareManagerFlagLibraryTest is Test {
    using ShareManagerFlagLibrary for uint256;

    function testSetAndHasMintPause() external pure {
        uint256 flags = 0;
        flags = flags.setHasMintPause(true);
        assertTrue(flags.hasMintPause());

        flags = flags.setHasMintPause(false);
        assertFalse(flags.hasMintPause());
    }

    function testSetAndHasBurnPause() external pure {
        uint256 flags = 0;
        flags = flags.setHasBurnPause(true);
        assertTrue(flags.hasBurnPause());

        flags = flags.setHasBurnPause(false);
        assertFalse(flags.hasBurnPause());
    }

    function testSetAndHasTransferPause() external pure {
        uint256 flags = 0;
        flags = flags.setHasTransferPause(true);
        assertTrue(flags.hasTransferPause());

        flags = flags.setHasTransferPause(false);
        assertFalse(flags.hasTransferPause());
    }

    function testSetAndHasWhitelist() external pure {
        uint256 flags = 0;
        flags = flags.setHasWhitelist(true);
        assertTrue(flags.hasWhitelist());

        flags = flags.setHasWhitelist(false);
        assertFalse(flags.hasWhitelist());
    }

    function testSetAndHasBlacklist() external pure {
        uint256 flags = 0;
        flags = flags.setHasBlacklist(true);
        assertTrue(flags.hasBlacklist());

        flags = flags.setHasBlacklist(false);
        assertFalse(flags.hasBlacklist());
    }

    function testSetAndHasTransferWhitelist() external pure {
        uint256 flags = 0;
        flags = flags.setHasTransferWhitelist(true);
        assertTrue(flags.hasTransferWhitelist());

        flags = flags.setHasTransferWhitelist(false);
        assertFalse(flags.hasTransferWhitelist());
    }

    function testSetAndGetGlobalLockup() external pure {
        uint256 flags = 0;
        uint32 lockup = 123456;
        flags = flags.setGlobalLockup(lockup);

        assertEq(flags.getGlobalLockup(), lockup);

        flags = flags.setGlobalLockup(0);
        assertEq(flags.getGlobalLockup(), 0);
    }

    function testSetAndGetTargetedLockup() external pure {
        uint256 flags = 0;
        uint32 lockup = 987654321;
        flags = flags.setTargetedLockup(lockup);

        assertEq(flags.getTargetedLockup(), lockup);

        flags = flags.setTargetedLockup(0);
        assertEq(flags.getTargetedLockup(), 0);
    }

    function testSetAllAndExtractIndependently() external pure {
        uint256 flags = 0;
        flags = flags.setHasMintPause(true);
        flags = flags.setHasBurnPause(true);
        flags = flags.setHasTransferPause(true);
        flags = flags.setHasWhitelist(true);
        flags = flags.setHasBlacklist(true);
        flags = flags.setHasTransferWhitelist(true);
        flags = flags.setGlobalLockup(42);
        flags = flags.setTargetedLockup(77);

        assertTrue(flags.hasMintPause());
        assertTrue(flags.hasBurnPause());
        assertTrue(flags.hasTransferPause());
        assertTrue(flags.hasWhitelist());
        assertTrue(flags.hasBlacklist());
        assertTrue(flags.hasTransferWhitelist());
        assertEq(flags.getGlobalLockup(), 42);
        assertEq(flags.getTargetedLockup(), 77);
    }
}
