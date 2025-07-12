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

    /// @notice A compact representation of a function call (limited to 4-byte selector)
    struct CompactCall {
        address who; // Caller address
        address where; // Target contract
        bytes4 selector; // Function selector
    }

    /// @notice An extended function call representation with full calldata and value
    struct ExtendedCall {
        address who; // Caller address
        address where; // Target contract
        uint256 value; // ETH value sent
        bytes data; // Full calldata
    }

    /// @notice Internal storage struct used by the Verifier
    struct VerifierStorage {
        address vault; // AccessControl-based role manager
        bytes32 merkleRoot; // Root for merkle-based verification
        EnumerableSet.Bytes32Set compactCallHashes; // Set of allowed compact call hashes
        mapping(bytes32 => CompactCall) compactCalls; // Mapping from hash to CompactCall
    }

    /// @notice Enum defining the verification method used for a call
    enum VerificationType {
        ONCHAIN_COMPACT, // Direct on-chain check against pre-approved CompactCall list
        MERKLE_COMPACT, // Merkle proof for a CompactCall
        MERKLE_EXTENDED, // Merkle proof for a full ExtendedCall
        CUSTOM_VERIFIER // Delegation to external verifier implementing ICustomVerifier

    }

    /// @notice Struct bundling proof and encoded call data for verification
    struct VerificationPayload {
        VerificationType verificationType; // Type of verification being used
        bytes verificationData; // Encoded data used in hash comparisons
        bytes32[] proof; // Merkle proof (if applicable)
    }

    /// @notice Role identifier for setting Merkle root
    function SET_MERKLE_ROOT_ROLE() external view returns (bytes32);

    /// @notice Role identifier for permitted callers of verification
    function CALLER_ROLE() external view returns (bytes32);

    /// @notice Role identifier for allowing new CompactCalls
    function ALLOW_CALL_ROLE() external view returns (bytes32);

    /// @notice Role identifier for removing CompactCalls
    function DISALLOW_CALL_ROLE() external view returns (bytes32);

    /// @notice Returns the vault contract managing roles
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

    /// @notice Returns whether a given call passes verification (does not revert)
    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        VerificationPayload calldata verificationPayload
    ) external view returns (bool);

    /// @notice Sets the Merkle root used for verification (only callable by authorized role)
    function setMerkleRoot(bytes32 merkleRoot_) external;

    /// @notice Adds a list of CompactCalls to the allowlist (only callable by authorized role)
    function allowCalls(CompactCall[] calldata compactCalls) external;

    /// @notice Removes a list of CompactCalls from the allowlist (only callable by authorized role)
    function disallowCalls(CompactCall[] calldata compactCalls) external;
}
