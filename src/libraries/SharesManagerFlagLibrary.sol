// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library SharesManagerFlagLibrary {
    function hasDepositQueues(uint256 mask) internal pure returns (bool) {
        return (mask & 0x1) != 0;
    }

    function hasWithdrawalQueues(uint256 mask) internal pure returns (bool) {
        return (mask & 0x2) != 0;
    }

    function hasMintPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x4) != 0;
    }

    function hasBurnPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x8) != 0;
    }

    function hasTransferPause(uint256 mask) internal pure returns (bool) {
        return (mask & 0x10) != 0;
    }

    function hasTargetedLockup(uint256 mask) internal pure returns (bool) {
        return (mask & 0x20) != 0;
    }

    function hasGlobalLockup(uint256 mask) internal pure returns (bool) {
        return (mask & 0x40) != 0;
    }

    function hasMappingWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x80) != 0;
    }

    function hasMerkleWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x100) != 0;
    }

    function hasBlackList(uint256 mask) internal pure returns (bool) {
        return (mask & 0x200) != 0;
    }

    function getLockupPeriod(uint256 mask) internal pure returns (uint32) {
        return uint32((mask >> 10) & type(uint32).max);
    }

    function setHasDepositQueues(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x1) : (mask & ~uint256(0x1));
    }

    function setHasWithdrawalQueues(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x2) : (mask & ~uint256(0x2));
    }

    function setHasMintPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x4) : (mask & ~uint256(0x4));
    }

    function setHasBurnPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x8) : (mask & ~uint256(0x8));
    }

    function setHasTransferPause(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x10) : (mask & ~uint256(0x10));
    }

    function setHasTargetedLockup(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x20) : (mask & ~uint256(0x20));
    }

    function setHasGlobalLockup(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x40) : (mask & ~uint256(0x40));
    }

    function setHasMappingWhitelist(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x80) : (mask & ~uint256(0x80));
    }

    function setHasMerkleWhitelist(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x100) : (mask & ~uint256(0x100));
    }

    function setHasBlackList(uint256 mask, bool value) internal pure returns (uint256) {
        return value ? (mask | 0x200) : (mask & ~uint256(0x200));
    }

    function setLockupPeriod(uint256 mask, uint32 period) internal pure returns (uint256) {
        return (mask & ~uint256(0xFFFFFFFF << 10)) | (uint256(period) << 10);
    }
}
