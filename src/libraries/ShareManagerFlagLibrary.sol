// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IShareManager.sol";

library ShareManagerFlagLibrary {
    function hasMintPause(uint256 mask) internal pure returns (bool) {
        return (mask & 1) != 0;
    }

    function hasBurnPause(uint256 mask) internal pure returns (bool) {
        return (mask & 2) != 0;
    }

    function hasTransferPause(uint256 mask) internal pure returns (bool) {
        return (mask & 4) != 0;
    }

    function hasWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 8) != 0;
    }

    function hasTransferWhitelist(uint256 mask) internal pure returns (bool) {
        return (mask & 16) != 0;
    }

    function getGlobalLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 5);
    }

    function getTargetedLockup(uint256 mask) internal pure returns (uint32) {
        return uint32(mask >> 37);
    }

    function createMask(IShareManager.Flags calldata f) internal pure returns (uint256) {
        return (f.hasMintPause ? 1 : 0) | (f.hasBurnPause ? 2 : 0) | (f.hasTransferPause ? 4 : 0)
            | (f.hasWhitelist ? 8 : 0) | (f.hasTransferWhitelist ? 16 : 0) | (uint256(f.globalLockup) << 5)
            | (uint256(f.targetedLockup) << 37);
    }
}
