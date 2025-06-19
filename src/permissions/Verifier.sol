// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/IVerifier.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";

contract Verifier is IVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 private immutable _verifierStorageSlot;

    modifier onlyRole(bytes32 role) {
        require(primaryACL().hasRole(role, _msgSender()), "Verifier: caller does not have the required role");
        _;
    }

    constructor(string memory name_, uint256 version_) {
        _verifierStorageSlot = SlotLibrary.getSlot("Verifier", name_, version_);
        _disableInitializers();
    }

    // View functions

    function primaryACL() public view returns (IAccessControl) {
        return IAccessControl(_verifierStorage().primaryACL);
    }

    function secondaryACL() public view returns (IAccessControl) {
        return IAccessControl(_verifierStorage().secondaryACL);
    }

    function merkleRoot() public view returns (bytes32) {
        return _verifierStorage().merkleRoot;
    }

    function isAllowedCall(address who, address where, bytes calldata data) public view returns (bool) {
        if (data.length < 4) {
            return false;
        }
        return _verifierStorage().hashedAllowedCalls.contains(hashCall(who, where, bytes4(data[:4])));
    }

    function allowedCalls() public view returns (uint256) {
        return _verifierStorage().hashedAllowedCalls.length();
    }

    function allowedCallAt(uint256 index) public view returns (Call memory) {
        VerifierStorage storage $ = _verifierStorage();
        require(index < $.hashedAllowedCalls.length(), "Verifier: index out of bounds");
        bytes32 key = $.hashedAllowedCalls.at(index);
        return _verifierStorage().allowedCalls[key];
    }

    function hashCall(address who, address where, bytes4 selector) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(who, where, selector));
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata data,
        VerificationPayload calldata verificationPayload
    ) external view {
        require(getVerificationResult(who, where, value, data, verificationPayload), "Verifier: verification failed");
    }

    function getVerificationResult(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        VerificationPayload calldata verificationPayload
    ) public view virtual returns (bool) {
        if (!primaryACL().hasRole(PermissionsLibrary.CALL_ROLE, who)) {
            return false;
        }

        if (verificationPayload.verificationType == VerficationType.VERIFIER_ACL) {
            return isAllowedCall(who, where, callData);
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

        if (verificationPayload.verificationType == VerficationType.PRIMARY_ACL) {
            bytes32 requiredRole = abi.decode(verificationPayload.verificationData, (bytes32));
            return primaryACL().hasRole(requiredRole, who);
        } else if (verificationPayload.verificationType == VerficationType.SECONDARY_ACL) {
            IAccessControl secondaryACL_ = secondaryACL();
            if (address(secondaryACL_) == address(0)) {
                return false;
            }
            bytes32 requiredRole = abi.decode(verificationPayload.verificationData, (bytes32));
            return secondaryACL_.hasRole(requiredRole, who);
        } else if (verificationPayload.verificationType == VerficationType.VERIFIER) {
            return ICustomVerifier(verificationPayload.verifier).verifyCall(
                who, where, value, callData, verificationPayload.verificationData
            );
        } else {
            return false;
        }
    }

    // Mutable functions

    function initialize(bytes calldata initParams) external initializer {
        (address primaryACL_, bytes32 merkleRoot_) = abi.decode(initParams, (address, bytes32));
        require(primaryACL_ != address(0), "Verifier: zero primary ACL address");
        _verifierStorage().primaryACL = primaryACL_;
        if (merkleRoot_ != bytes32(0)) {
            _verifierStorage().merkleRoot = merkleRoot_;
        }
    }

    function setSecondaryACL(address secondaryACL_) external onlyRole(PermissionsLibrary.SET_SECONDARY_ACL_ROLE) {
        require(secondaryACL_ != address(0), "Verifier: zero secondary ACL address");
        _verifierStorage().secondaryACL = secondaryACL_;
    }

    function setMerkleRoot(bytes32 merkleRoot_) external onlyRole(PermissionsLibrary.SET_MERKLE_ROOT_ROLE) {
        require(merkleRoot_ != bytes32(0), "Verifier: zero merkle root");
        _verifierStorage().merkleRoot = merkleRoot_;
    }

    function addAllowedCalls(address[] calldata callers, address[] calldata targets, bytes4[] calldata selectors)
        external
        onlyRole(PermissionsLibrary.ADD_ALLOWED_CALLS_ROLE)
    {
        uint256 n = callers.length;
        if (n != targets.length || n != selectors.length) {
            revert("Verifier: arrays length mismatch");
        }
        EnumerableSet.Bytes32Set storage hashedAllowedCalls_ = _verifierStorage().hashedAllowedCalls;
        for (uint256 i = 0; i < n; i++) {
            bytes32 hash_ = hashCall(callers[i], targets[i], selectors[i]);
            if (!hashedAllowedCalls_.add(hash_)) {
                revert("Verifier: call already allowed");
            }
        }
    }

    function removeAllowedCalls(address[] calldata callers, address[] calldata targets, bytes4[] calldata selectors)
        external
        onlyRole(PermissionsLibrary.REMOVE_ALLOWED_CALLS_ROLE)
    {
        uint256 n = callers.length;
        if (n != targets.length || n != selectors.length) {
            revert("Verifier: arrays length mismatch");
        }
        EnumerableSet.Bytes32Set storage hashedAllowedCalls_ = _verifierStorage().hashedAllowedCalls;
        for (uint256 i = 0; i < n; i++) {
            bytes32 hash_ = hashCall(callers[i], targets[i], selectors[i]);
            if (!hashedAllowedCalls_.remove(hash_)) {
                revert("Verifier: call not allowed");
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
