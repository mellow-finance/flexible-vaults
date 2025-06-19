// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

interface IConsensus {
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

    function initialize(address owner_) external;

    function setThreshold(uint256 threshold) external;

    function addSigner(address signer, uint256 threshold_, SignatureType signatureType) external;

    function removeSigner(address signer, uint256 threshold_) external;
}
