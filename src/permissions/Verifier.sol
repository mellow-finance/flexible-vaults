// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/IVerifier.sol";

import "../libraries/SlotLibrary.sol";

contract Verifier is IVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("permissions.Verifier.SET_MERKLE_ROOT_ROLE");
    bytes32 public constant CALL_ROLE = keccak256("permissions.Verifier.CALL_ROLE");
    bytes32 public constant ALLOW_CALL_ROLE = keccak256("permissions.Verifier.ALLOW_CALL_ROLE");
    bytes32 public constant DISALLOW_CALL_ROLE = keccak256("permissions.Verifier.DISALLOW_CALL_ROLE");
    bytes32 private immutable _verifierStorageSlot;

    modifier onlyRole(bytes32 role) {
        if (!vault().hasRole(role, _msgSender())) {
            revert Forbidden();
        }
        _;
    }

    constructor(string memory name_, uint256 version_) {
        _verifierStorageSlot = SlotLibrary.getSlot("Verifier", name_, version_);
        _disableInitializers();
    }

    // View functions

    function vault() public view returns (IAccessControl) {
        return IAccessControl(_verifierStorage().vault);
    }

    function merkleRoot() public view returns (bytes32) {
        return _verifierStorage().merkleRoot;
    }

    function allowedCalls() public view returns (uint256) {
        return _verifierStorage().compactCallHashes.length();
    }

    function allowedCallAt(uint256 index) public view returns (CompactCall memory) {
        VerifierStorage storage $ = _verifierStorage();
        bytes32 hash_ = $.compactCallHashes.at(index);
        return $.compactCalls[hash_];
    }

    function isAllowedCall(address who, address where, bytes calldata callData) public view returns (bool) {
        return callData.length >= 4
            && _verifierStorage().compactCallHashes.contains(hashCall(CompactCall(who, where, bytes4(callData[:4]))));
    }

    function hashCall(CompactCall memory call) public pure returns (bytes32) {
        return keccak256(abi.encode(call.who, call.where, call.selector));
    }

    function hashCall(ExtendedCall memory call) public pure returns (bytes32) {
        return keccak256(abi.encode(call.who, call.where, call.value, call.data));
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata verificationPayload
    ) external view {
        if (!getVerificationResult(who, where, value, data, verificationPayload)) {
            revert VerificationFailed();
        }
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

        if (verificationPayload.verificationType == VerficationType.ONCHAIN_COMPACT) {
            return isAllowedCall(who, where, callData);
        }

        bytes calldata verificationData = verificationPayload.verificationData;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(verificationPayload.verificationType, keccak256(verificationData))))
        );
        if (!MerkleProof.verify(verificationPayload.proof, merkleRoot(), leaf)) {
            return false;
        }

        if (verificationPayload.verificationType == VerficationType.MERKLE_EXTENDED) {
            return hashCall(ExtendedCall(who, where, value, callData)) == bytes32(verificationData);
        } else if (verificationPayload.verificationType == VerficationType.MERKLE_COMPACT) {
            return callData.length >= 4
                && hashCall(CompactCall(who, where, bytes4(callData[:4]))) == bytes32(verificationData);
        } else if (verificationPayload.verificationType == VerficationType.CUSTOM_VERIFIER) {
            address verifier;
            assembly {
                verifier := calldataload(verificationData.offset)
            }
            return ICustomVerifier(verifier).verifyCall(who, where, value, callData, verificationData[0x20:]);
        } else {
            return false;
        }
    }

    // Mutable functions

    function initialize(bytes calldata initParams) external initializer {
        (address vault_, bytes32 merkleRoot_) = abi.decode(initParams, (address, bytes32));
        if (vault_ == address(0)) {
            revert ValueZero();
        }
        _verifierStorage().vault = vault_;
        if (merkleRoot_ != bytes32(0)) {
            _verifierStorage().merkleRoot = merkleRoot_;
        }
    }

    function setMerkleRoot(bytes32 merkleRoot_) external onlyRole(SET_MERKLE_ROOT_ROLE) {
        if (merkleRoot_ == bytes32(0)) {
            revert ValueZero();
        }
        _verifierStorage().merkleRoot = merkleRoot_;
    }

    function allowCalls(CompactCall[] calldata compactCalls) external onlyRole(ALLOW_CALL_ROLE) {
        VerifierStorage storage $ = _verifierStorage();
        mapping(bytes32 => CompactCall) storage compactCalls_ = $.compactCalls;
        EnumerableSet.Bytes32Set storage compactCallHashes_ = $.compactCallHashes;
        for (uint256 i = 0; i < compactCalls.length; i++) {
            bytes32 hash_ = hashCall(compactCalls[i]);
            if (compactCallHashes_.add(hash_)) {
                compactCalls_[hash_] = compactCalls[i];
            } else {
                revert CompactCallAlreadyAllowed(compactCalls[i].who, compactCalls[i].where, compactCalls[i].selector);
            }
        }
    }

    function disallowCalls(CompactCall[] calldata compactCalls) external onlyRole(DISALLOW_CALL_ROLE) {
        VerifierStorage storage $ = _verifierStorage();
        mapping(bytes32 => CompactCall) storage compactCalls_ = $.compactCalls;
        EnumerableSet.Bytes32Set storage compactCallHashes_ = $.compactCallHashes;
        for (uint256 i = 0; i < compactCalls.length; i++) {
            bytes32 hash_ = hashCall(compactCalls[i]);
            if (compactCallHashes_.remove(hash_)) {
                compactCalls_[hash_] = compactCalls[i];
            } else {
                revert CompactCallNotFound(compactCalls[i].who, compactCalls[i].where, compactCalls[i].selector);
            }
        }
    }

    // Internal functions

    function _verifierStorage() internal view returns (VerifierStorage storage $) {
        bytes32 slot = _verifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
