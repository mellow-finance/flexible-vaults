// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/SlotLibrary.sol";
import "./CustomVerifier.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BaseVerifier is ContextUpgradeable {
    enum VerficationType {
        ACL,
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

    struct BaseVefifierStorage {
        IAccessControl vault;
        bytes32 merkleRoot;
    }

    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("BASE_VERIFIER:SET_MERKLE_ROOT_ROLE");
    bytes32 public constant CALL_ROLE = keccak256("BASE_VERIFIER:CALL_ROLE");
    bytes32 private immutable _baseVerifierStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _baseVerifierStorageSlot = SlotLibrary.getSlot("BaseVerifier", name_, version_);
        _disableInitializers();
    }

    function initialize(address vault_, bytes32 merkleRoot_) external initializer {
        require(vault_ != address(0), "BaseVerifier: zero vault address");
        _baseVerifierStorage().vault = IAccessControl(vault_);
        if (merkleRoot_ != bytes32(0)) {
            _baseVerifierStorage().merkleRoot = merkleRoot_;
        }
    }

    function vault() public view returns (IAccessControl) {
        return _baseVerifierStorage().vault;
    }

    function merkleRoot() public view returns (bytes32) {
        return _baseVerifierStorage().merkleRoot;
    }

    function setMerkleRoot(bytes32 merkleRoot_) external {
        require(
            vault().hasRole(SET_MERKLE_ROOT_ROLE, _msgSender()),
            "BaseVerifier: only admin can set merkle root"
        );
        require(merkleRoot_ != bytes32(0), "BaseVerifier: zero merkle root");
        _baseVerifierStorage().merkleRoot = merkleRoot_;
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata verificationPayload
    ) external view {
        require(
            getVerificationResult(who, where, value, data, verificationPayload),
            "BaseVerifier: verification failed"
        );
    }

    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        VerificationPayload calldata verificationPayload
    ) public view virtual returns (bool) {
        if (!vault().hasRole(CALL_ROLE, who)) {
            return false;
        }
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        verificationPayload.verificationType,
                        verificationPayload.verifier,
                        keccak256(verificationPayload.verificationData)
                    )
                )
            )
        );
        if (!MerkleProof.verify(verificationPayload.proof, merkleRoot(), leaf)) {
            return false;
        }

        if (verificationPayload.verificationType == VerficationType.ACL) {
            bytes32 requiredRole = abi.decode(verificationPayload.verificationData, (bytes32));
            return vault().hasRole(requiredRole, who);
        } else {
            return CustomVerifier(verificationPayload.verifier).verifyCall(
                who, where, value, callData, verificationPayload.verificationData
            );
        }
    }

    function _baseVerifierStorage() internal view returns (BaseVefifierStorage storage $) {
        bytes32 slot = _baseVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
