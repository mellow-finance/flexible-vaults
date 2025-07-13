// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/ICustomVerifier.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title BitmaskVerifier
/// @notice Verifier contract implementing selective calldata hashing using bitmasking rules.
/// @dev Enables flexible permissioning by allowing dynamic verification of transaction intent through partial data matching.
contract BitmaskVerifier is ICustomVerifier {
    /// @notice Computes a hash of a call using selective masking over its fields.
    /// @dev The hash is computed in the following sequence:
    /// 1. Hashing `who` using `bitmask[0:32]`
    /// 2. Hashing `where` using `bitmask[32:64]`
    /// 3. Hashing `value` using `bitmask[64:96]`
    /// 4. Iteratively hashing each byte of `data` masked with `bitmask[i + 96]`
    ///
    /// This allows whitelisting specific parts of calldata or sender/target/value.
    ///
    /// @param bitmask A byte array encoding which bytes should be included in the hash.
    ///        - [0:32]    Mask for `who` (caller)
    ///        - [32:64]   Mask for `where` (target contract)
    ///        - [64:96]   Mask for `value` (ETH sent)
    ///        - [96:]     Mask for each byte of `data` (calldata)
    /// @param who Caller address.
    /// @param where Target contract address.
    /// @param value ETH value to be sent with the call.
    /// @param data Full calldata of the call.
    /// @return Hash of the masked components using `keccak256`.
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

    /// @notice Verifies whether the provided call matches a pre-approved hash using a given bitmask.
    /// @dev The expected hash and bitmask are ABI-encoded in `verificationData`.
    /// - `verificationData = abi.encode(expectedHash, bitmask)`
    /// - Function reverts to false if bitmask length does not match (data.length + 96).
    ///
    /// @param who Caller address of the original call.
    /// @param where Target contract address.
    /// @param value ETH value to be sent.
    /// @param data Calldata for the function call.
    /// @param verificationData ABI-encoded data containing:
    ///        - bytes32 expectedHash
    ///        - bytes bitmask (variable length)
    /// @return True if the calculated masked hash matches the expected hash, false otherwise.
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
