// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/ICustomVerifier.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract BitmaskVerifier is ICustomVerifier {
    function calculateHash(bytes calldata bitmask, address who, address where, uint256 value, bytes calldata data)
        public
        pure
        returns (bytes32)
    {
        bytes32 hash_;
        hash_ = keccak256(bytes.concat(hash_, bytes32(bitmask[0:32]) & bytes32(bytes20(who))));
        hash_ = keccak256(bytes.concat(hash_, bytes32(bitmask[32:64]) & bytes32(bytes20(where))));
        hash_ = keccak256(bytes.concat(hash_, bytes32(bitmask[64:96]) & bytes32(value)));
        for (uint256 i = 0; i < data.length; i++) {
            hash_ = keccak256(bytes.concat(hash_, (data[i] & bitmask[i + 96])));
        }
        return hash_;
    }

    function verifyCall(address who, address where, uint256 value, bytes calldata data, bytes calldata verificationData)
        public
        pure
        returns (bool)
    {
        bytes32 verificationHash_;
        bytes calldata bitmask;
        assembly {
            verificationHash_ := calldataload(verificationData.offset)
            let temp := add(verificationData.offset, calldataload(add(verificationData.offset, 0x20)))
            bitmask.offset := add(temp, 0x20)
            bitmask.length := calldataload(temp)
        }
        if (data.length + 0x60 != bitmask.length) {
            return false;
        }
        bytes32 hash_ = calculateHash(bitmask, who, where, value, data);
        if (hash_ != verificationHash_) {
            return false;
        }
        return true;
    }
}
