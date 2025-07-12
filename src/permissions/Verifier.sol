// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/IVerifier.sol";

import "../libraries/SlotLibrary.sol";

contract Verifier is IVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @inheritdoc IVerifier
    bytes32 public constant SET_MERKLE_ROOT_ROLE = keccak256("permissions.Verifier.SET_MERKLE_ROOT_ROLE");
    /// @inheritdoc IVerifier
    bytes32 public constant CALLER_ROLE = keccak256("permissions.Verifier.CALLER_ROLE");
    /// @inheritdoc IVerifier
    bytes32 public constant ALLOW_CALL_ROLE = keccak256("permissions.Verifier.ALLOW_CALL_ROLE");
    /// @inheritdoc IVerifier
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

    /// @inheritdoc IVerifier
    function vault() public view returns (IAccessControl) {
        return IAccessControl(_verifierStorage().vault);
    }

    /// @inheritdoc IVerifier
    function merkleRoot() public view returns (bytes32) {
        return _verifierStorage().merkleRoot;
    }

    /// @inheritdoc IVerifier
    function allowedCalls() public view returns (uint256) {
        return _verifierStorage().compactCallHashes.length();
    }

    /// @inheritdoc IVerifier
    function allowedCallAt(uint256 index) public view returns (CompactCall memory) {
        VerifierStorage storage $ = _verifierStorage();
        bytes32 hash_ = $.compactCallHashes.at(index);
        return $.compactCalls[hash_];
    }

    /// @inheritdoc IVerifier
    function isAllowedCall(address who, address where, bytes calldata callData) public view returns (bool) {
        return callData.length >= 4
            && _verifierStorage().compactCallHashes.contains(hashCall(CompactCall(who, where, bytes4(callData[:4]))));
    }

    /// @inheritdoc IVerifier
    function hashCall(CompactCall memory call) public pure returns (bytes32) {
        return keccak256(abi.encode(call.who, call.where, call.selector));
    }

    /// @inheritdoc IVerifier
    function hashCall(ExtendedCall memory call) public pure returns (bytes32) {
        return keccak256(abi.encode(call.who, call.where, call.value, call.data));
    }

    /// @inheritdoc IVerifier
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata payload
    ) external view {
        if (!getVerificationResult(who, where, value, data, payload)) {
            revert VerificationFailed();
        }
    }

    /// @inheritdoc IVerifier
    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata payload
    ) public view returns (bool) {
        if (!vault().hasRole(CALLER_ROLE, who)) {
            return false;
        }

        if (payload.verificationType == VerificationType.ONCHAIN_COMPACT) {
            return isAllowedCall(who, where, data);
        }

        bytes calldata verificationData = payload.verificationData;
        bytes32 leaf =
            keccak256(bytes.concat(keccak256(abi.encode(payload.verificationType, keccak256(verificationData)))));
        if (!MerkleProof.verify(payload.proof, merkleRoot(), leaf)) {
            return false;
        }

        if (payload.verificationType == VerificationType.MERKLE_EXTENDED) {
            return hashCall(ExtendedCall(who, where, value, data)) == bytes32(verificationData);
        } else if (payload.verificationType == VerificationType.MERKLE_COMPACT) {
            return data.length >= 4 && hashCall(CompactCall(who, where, bytes4(data[:4]))) == bytes32(verificationData);
        } else if (payload.verificationType == VerificationType.CUSTOM_VERIFIER) {
            address verifier;
            assembly {
                verifier := calldataload(verificationData.offset)
            }
            return ICustomVerifier(verifier).verifyCall(who, where, value, data, verificationData[0x20:]);
        } else {
            return false;
        }
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata initParams) external initializer {
        (address vault_, bytes32 merkleRoot_) = abi.decode(initParams, (address, bytes32));
        if (vault_ == address(0)) {
            revert ZeroValue();
        }
        VerifierStorage storage $ = _verifierStorage();
        $.vault = vault_;
        $.merkleRoot = merkleRoot_;
        emit Initialized(initParams);
    }

    /// @inheritdoc IVerifier
    function setMerkleRoot(bytes32 merkleRoot_) external onlyRole(SET_MERKLE_ROOT_ROLE) {
        _verifierStorage().merkleRoot = merkleRoot_;
    }

    /// @inheritdoc IVerifier
    function allowCalls(CompactCall[] calldata compactCalls) external onlyRole(ALLOW_CALL_ROLE) {
        VerifierStorage storage $ = _verifierStorage();
        mapping(bytes32 => CompactCall) storage compactCalls_ = $.compactCalls;
        EnumerableSet.Bytes32Set storage compactCallHashes_ = $.compactCallHashes;
        for (uint256 i = 0; i < compactCalls.length; i++) {
            bytes32 hash_ = hashCall(compactCalls[i]);
            if (!compactCallHashes_.add(hash_)) {
                revert CompactCallAlreadyAllowed(compactCalls[i].who, compactCalls[i].where, compactCalls[i].selector);
            }
            compactCalls_[hash_] = compactCalls[i];
        }
    }

    /// @inheritdoc IVerifier
    function disallowCalls(CompactCall[] calldata compactCalls) external onlyRole(DISALLOW_CALL_ROLE) {
        VerifierStorage storage $ = _verifierStorage();
        mapping(bytes32 => CompactCall) storage compactCalls_ = $.compactCalls;
        EnumerableSet.Bytes32Set storage compactCallHashes_ = $.compactCallHashes;
        for (uint256 i = 0; i < compactCalls.length; i++) {
            bytes32 hash_ = hashCall(compactCalls[i]);
            if (!compactCallHashes_.remove(hash_)) {
                revert CompactCallNotFound(compactCalls[i].who, compactCalls[i].where, compactCalls[i].selector);
            }
            compactCalls_[hash_] = compactCalls[i];
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
