// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../factories/IFactoryEntity.sol";

interface IConsensus is IFactoryEntity {
    error InvalidSignatures(bytes32 orderHash, Signature[] signatures);
    error InvalidThreshold(uint256 threshold);
    error SignerAlreadyExists(address signer);
    error SignerNotFound(address signer);
    error ZeroAddress();

    enum SignatureType {
        EIP712,
        EIP1271
    }

    struct Signature {
        address signer;
        bytes signature;
    }

    struct ConsensusStorage {
        EnumerableMap.AddressToUintMap signers;
        uint256 threshold;
    }

    // View functions

    function checkSignatures(bytes32 orderHash, Signature[] calldata signatures) external view returns (bool);

    function requireValidSignatures(bytes32 orderHash, Signature[] calldata signatures) external view;

    function threshold() external view returns (uint256);

    function signers() external view returns (uint256);

    function signerAt(uint256 index) external view returns (address, SignatureType);

    function isSigner(address account) external view returns (bool);

    // Mutable functions

    function initialize(bytes calldata data) external;

    function setThreshold(uint256 threshold) external;

    function addSigner(address signer, uint256 threshold_, SignatureType signatureType) external;

    function removeSigner(address signer, uint256 threshold_) external;

    // Events

    event ThresholdSet(uint256 threshold);
    event SignerAdded(address indexed signer, SignatureType signatureType, uint256 threshold);
    event SignerRemoved(address indexed signer, uint256 threshold);
}
