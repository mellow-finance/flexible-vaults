// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";
import "./ICustomVerifier.sol";

/// @notice Interface for the Verifier contract, used to validate allowed calls via multiple verification mechanisms
interface IVerifier is IFactoryEntity {
    /// @notice Thrown when a caller lacks necessary permissions
    error Forbidden();

    /// @notice Thrown when a call fails verification
    error VerificationFailed();

    /// @notice Thrown when a required value (e.g. address) is zero
    error ZeroValue();

    /// @notice Thrown when input array lengths mismatch
    error InvalidLength();

    /// @notice Thrown when attempting to allow an already allowed CompactCall
    error CompactCallAlreadyAllowed(address who, address where, bytes4 selector);

    /// @notice Thrown when attempting to disallow a non-existent CompactCall
    error CompactCallNotFound(address who, address where, bytes4 selector);

    /// @notice Represents a minimal function call format using only selector-level granularity.
    /// @dev Used in compact verification where only caller, target, and function selector are validated.
    struct CompactCall {
        address who; // The address initiating the call (caller)
        address where; // The target contract address
        bytes4 selector; // 4-byte function selector (first 4 bytes of calldata)
    }

    /// @notice Represents a full function call with calldata and ETH value.
    /// @dev Used in extended verification types where arguments and call value must be validated.
    struct ExtendedCall {
        address who; // The address initiating the call (caller)
        address where; // The target contract address
        uint256 value; // ETH value sent with the call
        bytes data; // Full calldata (function selector + encoded arguments)
    }

    /// @notice Internal storage layout used by the Verifier contract.
    /// @dev Tracks verification configuration and access control data for calls made by the vault.
    struct VerifierStorage {
        address vault; // The vault that owns this verifier.
        bytes32 merkleRoot; // Root of the Merkle tree used in Merkle-based verification modes
        EnumerableSet.Bytes32Set compactCallHashes; // Set of approved hashed CompactCall entries for ONCHAIN_COMPACT verification types
        mapping(bytes32 => CompactCall) compactCalls; // Optional mapping to recover original CompactCall from hash
    }

    /// @notice Enum defining the method used to verify a function call authorization.
    enum VerificationType {
        /// @dev Compact on-chain verification.
        /// Checks if `keccak256(abi.encode(who, where, selector))` exists in the verifier's `compactCallHashes` set.
        ONCHAIN_COMPACT,
        /// @dev Merkle-based verification of a compact call.
        /// Validates a Merkle proof for `keccak256(abi.encode(who, where, selector))` against a stored Merkle root.
        MERKLE_COMPACT,
        /// @dev Merkle-based verification of an extended call.
        /// Validates a Merkle proof for `keccak256(abi.encode(who, where, value, data))` against a stored Merkle root.
        MERKLE_EXTENDED,
        /// @dev Delegated verification via external contract.
        /// Forwards call details to a custom verifier contract implementing `ICustomVerifier`.
        CUSTOM_VERIFIER
    }

    /// @notice Struct containing all inputs required to verify a delegated function call.
    struct VerificationPayload {
        /// @dev The method used to verify the delegated call.
        VerificationType verificationType;
        /// @dev Encoded payload to be verified, varies by verification type:
        /// - MERKLE_COMPACT: abi.encode(who, where, selector)
        /// - MERKLE_EXTENDED: abi.encode(who, where, value, callData)
        /// - CUSTOM_VERIFIER: abi.encodePacked(address customVerifier, customVerifierSpecificData)
        bytes verificationData;
        /// @dev Merkle proof used to validate the `verificationType` and `verificationData` for MERKLE_COMPACT,
        /// MERKLE_EXTENDED, and CUSTOM_VERIFIER types.
        bytes32[] proof;
    }

    /// @notice Role identifier for setting Merkle root
    function SET_MERKLE_ROOT_ROLE() external view returns (bytes32);

    /// @notice Role identifier for permitted callers
    function CALLER_ROLE() external view returns (bytes32);

    /// @notice Role identifier for allowing new CompactCalls
    function ALLOW_CALL_ROLE() external view returns (bytes32);

    /// @notice Role identifier for removing CompactCalls
    function DISALLOW_CALL_ROLE() external view returns (bytes32);

    /// @notice Returns the vault associated to this Verifier contract
    function vault() external view returns (IAccessControl);

    /// @notice Returns the current Merkle root
    function merkleRoot() external view returns (bytes32);

    /// @notice Returns number of currently allowed compact calls
    function allowedCalls() external view returns (uint256);

    /// @notice Returns the compact call at a specific index
    function allowedCallAt(uint256 index) external view returns (CompactCall memory);

    /// @notice Checks if a CompactCall is explicitly allowed
    function isAllowedCall(address who, address where, bytes calldata callData) external view returns (bool);

    /// @notice Computes the hash of a CompactCall
    function hashCall(CompactCall memory call) external pure returns (bytes32);

    /// @notice Computes the hash of an ExtendedCall
    function hashCall(ExtendedCall memory call) external pure returns (bytes32);

    /// @notice Validates a function call using the provided verification payload, reverts on failure
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata verificationPayload
    ) external view;

    /// @return bool Returns whether a given call passes verification
    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        VerificationPayload calldata verificationPayload
    ) external view returns (bool);

    /// @notice Sets the Merkle root used for verification
    function setMerkleRoot(bytes32 merkleRoot_) external;

    /// @notice Adds a list of CompactCalls to the allowlist
    function allowCalls(CompactCall[] calldata compactCalls) external;

    /// @notice Removes a list of CompactCalls from the allowlist
    function disallowCalls(CompactCall[] calldata compactCalls) external;
}
