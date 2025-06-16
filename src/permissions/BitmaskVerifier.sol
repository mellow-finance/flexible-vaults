// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/ICustomVerifier.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract BitmaskVerifier is ICustomVerifier {
    function calculateHash(bytes calldata bitmask, bytes memory data) public pure returns (bytes32) {
        bytes32 hash_;
        for (uint256 i = 0; i < data.length; i++) {
            if (bitmask[i] == 0) {
                continue;
            }
            hash_ = keccak256(abi.encodePacked(hash_, (data[i] & bitmask[i])));
        }
        return hash_;
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) public pure returns (bool) {
        bytes32 verificationHash_;
        bytes calldata bitmask;
        assembly {
            verificationHash_ := calldataload(verificationData.offset)
            let temp := add(verificationData.offset, calldataload(add(verificationData.offset, 0x20)))
            bitmask.offset := add(temp, 0x20)
            bitmask.length := calldataload(temp)
        }
        bytes memory fullData = abi.encode(who, where, value, callData);
        if (fullData.length != bitmask.length) {
            return false;
        }
        bytes32 hash_ = calculateHash(bitmask, fullData);
        if (hash_ != verificationHash_) {
            return false;
        }
        return true;
    }
}
