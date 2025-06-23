// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library ShareManagerFlagLibrary {
    function hasMintPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x1) != 0;
    }

    function setHasMintPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x1) : (mask & ~uint256(0x1));
    }

    function hasBurnPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x2) != 0;
    }

    function setHasBurnPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x2) : (mask & ~uint256(0x2));
    }

    function hasTransferPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x4) != 0;
    }

    function setHasTransferPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x4) : (mask & ~uint256(0x4));
    }

    function hasWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x8) != 0;
    }

    function setHasWhitelist(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x8) : (mask & ~uint256(0x8));
    }

    function hasBlacklist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x10) != 0;
    }

    function setHasBlacklist(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x10) : (mask & ~uint256(0x10));
    }

    function hasTransferWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x20) != 0;
    }

    function setHasTransferWhitelist(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x20) : (mask & ~uint256(0x20));
    }

    function getGlobalLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 6);
    }

    function setGlobalLockup(uint256 mask, uint32 lockup) internal pure returns (uint256) {
        return (mask & ~uint256(0xFFFFFFFF << 6)) | (uint256(lockup) << 6);
    }

    function getTargetedLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 38);
    }

    function setTargetedLockup(uint256 mask, uint32 lockup) internal pure returns (uint256) {
        return (mask & ~uint256(0xFFFFFFFF << 38)) | (uint256(lockup) << 38);
    }
}
