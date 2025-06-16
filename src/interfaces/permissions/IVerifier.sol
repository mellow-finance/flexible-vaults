// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ICustomVerifier.sol";

interface IVerifier {
    struct Call {
        address who;
        address where;
        bytes4 selector;
    }

    struct VerifierStorage {
        IAccessControl vault;
        bytes32 merkleRoot;
        EnumerableSet.Bytes32Set hashedAllowedCalls;
        mapping(bytes32 => Call) allowedCalls;
    }

    enum VerficationType {
        VERIFIER_ACL,
        VAULT_ACL,
        VERIFIER
    }

    struct VerificationPayload {
        // leaf:
        VerficationType verificationType;
        address verifier; // verifier == address(vault) if it is ACL, else - separate verifier contract
        bytes verificationData;
        // merkle proof:
        bytes32[] proof;
    }

    // View functions

    function vault() external view returns (IAccessControl);

    function merkleRoot() external view returns (bytes32);

    function isAllowedCall(address who, address where, bytes calldata data) external view returns (bool);

    function allowedCalls() external view returns (uint256);

    function allowedCallAt(uint256 index) external view returns (Call memory);

    function hashCall(address who, address where, bytes4 selector) external pure returns (bytes32);

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

    function initialize(address vault_, bytes32 merkleRoot_) external;

    function setMerkleRoot(bytes32 merkleRoot_) external;

    function addAllowedCalls(address[] calldata callers, address[] calldata targets, bytes4[] calldata selectors)
        external;

    function removeAllowedCalls(address[] calldata callers, address[] calldata targets, bytes4[] calldata selectors)
        external;
}
