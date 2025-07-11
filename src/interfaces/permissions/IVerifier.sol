// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";
import "./ICustomVerifier.sol";

interface IVerifier is IFactoryEntity {
    error Forbidden();
    error VerificationFailed();
    error ZeroValue();
    error InvalidLength();
    error CompactCallAlreadyAllowed(address who, address where, bytes4 selector);
    error CompactCallNotFound(address who, address where, bytes4 selector);

    struct CompactCall {
        address who;
        address where;
        bytes4 selector;
    }

    struct ExtendedCall {
        address who;
        address where;
        uint256 value;
        bytes data;
    }

    struct VerifierStorage {
        address vault;
        bytes32 merkleRoot;
        EnumerableSet.Bytes32Set compactCallHashes;
        mapping(bytes32 => CompactCall) compactCalls;
    }

    enum VerificationType {
        ONCHAIN_COMPACT,
        MERKLE_COMPACT,
        MERKLE_EXTENDED,
        CUSTOM_VERIFIER
    }

    struct VerificationPayload {
        // leaf:
        VerificationType verificationType;
        bytes verificationData;
        // merkle proof:
        bytes32[] proof;
    }

    // View functions

    function SET_MERKLE_ROOT_ROLE() external view returns (bytes32);
    function CALL_ROLE() external view returns (bytes32);
    function ALLOW_CALL_ROLE() external view returns (bytes32);
    function DISALLOW_CALL_ROLE() external view returns (bytes32);

    function vault() external view returns (IAccessControl);
    function merkleRoot() external view returns (bytes32);
    function allowedCalls() external view returns (uint256);
    function allowedCallAt(uint256 index) external view returns (CompactCall memory);
    function isAllowedCall(address who, address where, bytes calldata callData) external view returns (bool);
    function hashCall(CompactCall memory call) external pure returns (bytes32);
    function hashCall(ExtendedCall memory call) external pure returns (bytes32);
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata verificationPayload
    ) external view;
    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        VerificationPayload calldata verificationPayload
    ) external view returns (bool);

    // Mutable functions

    function setMerkleRoot(bytes32 merkleRoot_) external;
    function allowCalls(CompactCall[] calldata compactCalls) external;
    function disallowCalls(CompactCall[] calldata compactCalls) external;
}
