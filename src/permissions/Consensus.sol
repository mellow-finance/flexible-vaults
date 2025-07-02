// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/IConsensus.sol";

import "../libraries/SlotLibrary.sol";

contract Consensus is IConsensus, OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    bytes32 private immutable _consensusStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _consensusStorageSlot = SlotLibrary.getSlot("Consensus", name_, version_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc IConsensus
    function checkSignatures(bytes32 orderHash, Signature[] calldata signatures) public view returns (bool) {
        ConsensusStorage storage $ = _consensusStorage();
        if (signatures.length == 0 || signatures.length < $.threshold) {
            return false;
        }
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = signatures[i].signer;
            (bool exists, uint256 signatureTypeValue) = $.signers.tryGet(signer);
            if (!exists) {
                return false;
            }
            SignatureType signatureType = SignatureType(signatureTypeValue);
            if (signatureType == SignatureType.EIP712) {
                address recoveredSigner = ECDSA.recover(orderHash, signatures[i].signature);
                if (recoveredSigner == address(0) || recoveredSigner != signer) {
                    return false;
                }
            } else if (signatureType == SignatureType.EIP1271) {
                bytes4 magicValue = IERC1271(signer).isValidSignature(orderHash, signatures[i].signature);
                if (magicValue != IERC1271.isValidSignature.selector) {
                    return false;
                }
            } else {
                return false;
            }
        }
        return true;
    }

    /// @inheritdoc IConsensus
    function requireValidSignatures(bytes32 orderHash, Signature[] calldata signatures) external view {
        if (!checkSignatures(orderHash, signatures)) {
            revert InvalidSignatures(orderHash, signatures);
        }
    }

    /// @inheritdoc IConsensus
    function threshold() external view returns (uint256) {
        return _consensusStorage().threshold;
    }

    /// @inheritdoc IConsensus
    function signers() external view returns (uint256) {
        return _consensusStorage().signers.length();
    }

    /// @inheritdoc IConsensus
    function signerAt(uint256 index) external view returns (address signer, SignatureType signatureType) {
        ConsensusStorage storage $ = _consensusStorage();
        uint256 signatureTypeValue;
        (signer, signatureTypeValue) = $.signers.at(index);
        signatureType = SignatureType(signatureTypeValue);
    }

    /// @inheritdoc IConsensus
    function isSigner(address account) external view returns (bool) {
        ConsensusStorage storage $ = _consensusStorage();
        return $.signers.contains(account);
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        address owner_ = abi.decode(data, (address));
        __Ownable_init(owner_);
        emit Initialized(data);
    }

    /// @inheritdoc IConsensus
    function setThreshold(uint256 threshold_) external onlyOwner {
        ConsensusStorage storage $ = _consensusStorage();
        if (threshold_ == 0 || threshold_ > $.signers.length()) {
            revert InvalidThreshold(threshold_);
        }
        $.threshold = threshold_;
        emit ThresholdSet(threshold_);
    }

    /// @inheritdoc IConsensus
    function addSigner(address signer, uint256 threshold_, SignatureType signatureType) external onlyOwner {
        ConsensusStorage storage $ = _consensusStorage();
        if (signer == address(0)) {
            revert ZeroAddress();
        }
        if (!$.signers.set(signer, uint256(signatureType))) {
            revert SignerAlreadyExists(signer);
        }
        if (threshold_ == 0 || threshold_ > $.signers.length()) {
            revert InvalidThreshold(threshold_);
        }
        $.threshold = threshold_;
        emit SignerAdded(signer, signatureType, threshold_);
    }

    /// @inheritdoc IConsensus
    function removeSigner(address signer, uint256 threshold_) external onlyOwner {
        ConsensusStorage storage $ = _consensusStorage();
        if (!$.signers.remove(signer)) {
            revert SignerNotFound(signer);
        }
        if (threshold_ == 0 || threshold_ > $.signers.length()) {
            revert InvalidThreshold(threshold_);
        }
        $.threshold = threshold_;
        emit SignerRemoved(signer, threshold_);
    }

    // Internal functions

    function _consensusStorage() internal view returns (ConsensusStorage storage $) {
        bytes32 slot = _consensusStorageSlot;
        assembly {
            $.slot := slot
        }
        return $;
    }
}
