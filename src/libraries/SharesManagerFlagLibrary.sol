// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library SharesManagerFlagLibrary {
    function hasDepositQueues(uint256 mask) internal pure returns (bool) {
        return (mask & 0x1) != 0;
    }

    function hasRedeemQueues(uint256 mask) internal pure returns (bool) {
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

    function hasWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x20) != 0;
    }

    function hasBlacklist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x40) != 0;
    }

    function hasTransferWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 0x80) != 0;
    }

    function getGlobalLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 8);
    }

    function getTargetedLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 40);
    }
}
