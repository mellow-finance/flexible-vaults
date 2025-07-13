// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../factories/IFactoryEntity.sol";

/// @title IConsensus
/// @notice Interface for a Consensus contract that validates multisignature approvals via EIP-712 and EIP-1271.
/// @dev Enables off-chain consensus-based authorization for deposit and redemption queues or other vault operations.
///
/// # Overview
/// The `Consensus` contract acts as a cryptographic gatekeeper that validates signed messages from a trusted set of signers.
/// It supports both EIP-712 structured signatures and EIP-1271 contract-based signature validation, enabling:
/// - Multisignature validation for off-chain approvals.
/// - Compatibility with externally owned accounts (EOAs) and smart contract wallets (e.g., Safe).
///
/// This interface is typically used by modules like `SignatureQueue` that rely on off-chain consensus to approve user actions
/// without requiring full on-chain execution or delays.
interface IConsensus is IFactoryEntity {
    /// @notice Thrown when provided signatures are invalid or below the required threshold
    error InvalidSignatures(bytes32 orderHash, Signature[] signatures);

    /// @notice Thrown when attempting to set an invalid threshold (zero or above signer count)
    error InvalidThreshold(uint256 threshold);

    /// @notice Thrown when trying to add a signer that already exists
    error SignerAlreadyExists(address signer);

    /// @notice Thrown when trying to remove a signer that isn't in the signer set
    error SignerNotFound(address signer);

    /// @notice Thrown when a provided address is the zero address
    error ZeroAddress();

    /// @notice Supported signature schemes
    enum SignatureType {
        EIP712, // Regular ECDSA (offchain)
        EIP1271 // On-chain smart contract signature (e.g. Safe)

    }

    /// @notice Structure representing a signature and its signer
    struct Signature {
        address signer; // Address of the signer
        bytes signature; // Signature bytes (format depends on SignatureType)
    }

    /// @notice Internal storage layout for Consensus contract
    struct ConsensusStorage {
        EnumerableMap.AddressToUintMap signers; // Mapping of signer => SignatureType
        uint256 threshold; // Required number of valid signatures
    }

    /// @notice Returns true if the given signatures are valid and meet the current threshold
    /// @param orderHash The message hash that was signed
    /// @param signatures List of (signer, signature) entries
    function checkSignatures(bytes32 orderHash, Signature[] calldata signatures) external view returns (bool);

    /// @notice Verifies the given signatures or reverts if invalid
    /// @param orderHash The message hash that was signed
    /// @param signatures List of (signer, signature) entries
    function requireValidSignatures(bytes32 orderHash, Signature[] calldata signatures) external view;

    /// @notice Returns the current threshold of required valid signatures
    function threshold() external view returns (uint256);

    /// @notice Returns the number of registered signers
    function signers() external view returns (uint256);

    /// @notice Returns signer address and signature type at a given index
    /// @param index Index into the signer list
    function signerAt(uint256 index) external view returns (address, uint256);

    /// @notice Checks if the given address is a registered signer
    /// @param account Address to check
    function isSigner(address account) external view returns (bool);

    /// @notice Updates the threshold required to approve an operation
    /// @param threshold New threshold (must be > 0 and <= signer count)
    function setThreshold(uint256 threshold) external;

    /// @notice Adds a new signer and updates the threshold
    /// @param signer Signer address to add
    /// @param threshold_ New threshold to set after adding
    /// @param signatureType Signature type used by this signer
    function addSigner(address signer, uint256 threshold_, SignatureType signatureType) external;

    /// @notice Removes a signer and updates the threshold
    /// @param signer Signer address to remove
    /// @param threshold_ New threshold to set after removal
    function removeSigner(address signer, uint256 threshold_) external;

    /// @notice Emitted when the threshold is changed
    event ThresholdSet(uint256 indexed threshold);

    /// @notice Emitted when a signer is added
    event SignerAdded(address indexed signer, SignatureType signatureType);

    /// @notice Emitted when a signer is removed
    event SignerRemoved(address indexed signer);
}
