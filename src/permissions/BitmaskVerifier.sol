// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/ICustomVerifier.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title BitmaskVerifier
/// @notice Verifies low-level contract calls using a bitmask-based hash encoding.
///         Designed for intent-based permission systems where selected parts of calldata
///         are verified using a compact bitmasking scheme.
contract BitmaskVerifier is ICustomVerifier {
    /// @notice Computes a verification hash using a bitmask applied over call data fields.
    /// @param bitmask A byte array where each bit defines whether the corresponding byte of input is considered in hashing.
    ///        Layout:
    ///        - [0:32]    -> mask for `who`
    ///        - [32:64]   -> mask for `where`
    ///        - [64:96]   -> mask for `value`
    ///        - [96:]     -> mask for `data`
    /// @param who Caller address.
    /// @param where Target contract address.
    /// @param value ETH value to be sent.
    /// @param data Arbitrary calldata of the function being verified.
    /// @return Hash computed by successively combining masked fields using `keccak256`.
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

    /// @notice Verifies that a call matches a previously authorized hash using bitmask encoding.
    /// @param who Caller address to verify.
    /// @param where Target contract address.
    /// @param value ETH value to be sent with the call.
    /// @param data Calldata used in the intended call.
    /// @param verificationData Encoded structure containing:
    ///        - bytes32 expectedHash
    ///        - bytes calldata bitmask
    /// @return Whether the input parameters match the expected hash when processed with the provided bitmask.
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
        return verificationHash_ == calculateHash(bitmask, who, where, value, data);
    }
}
