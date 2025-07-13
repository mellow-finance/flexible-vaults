// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISignatureQueue.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

abstract contract SignatureQueue is
    ISignatureQueue,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable,
    ContextUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ISignatureQueue
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 orderId,address queue,address asset,address caller,address recipient,uint256 ordered,uint256 requested,uint256 deadline,uint256 nonce)"
    );

    /// @inheritdoc ISignatureQueue
    IFactory public immutable consensusFactory;

    bytes32 private immutable _signatureQueueStorageSlot;

    constructor(string memory name_, uint256 version_, address consensusFactory_) {
        _signatureQueueStorageSlot = SlotLibrary.getSlot("SignatureQueue", name_, version_);
        consensusFactory = IFactory(consensusFactory_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc ISignatureQueue
    function claimableOf(address) public view virtual returns (uint256) {}

    /// @inheritdoc ISignatureQueue
    function claim(address /* account */ ) external virtual returns (bool) {}

    /// @inheritdoc ISignatureQueue
    function handleReport(uint224, uint32) external view {}

    /// @inheritdoc ISignatureQueue
    function vault() public view returns (address) {
        return _signatureQueueStorage().vault;
    }

    /// @inheritdoc ISignatureQueue
    function asset() public view returns (address) {
        return _signatureQueueStorage().asset;
    }

    /// @inheritdoc ISignatureQueue
    function consensus() public view returns (IConsensus) {
        return IConsensus(_signatureQueueStorage().consensus);
    }

    /// @inheritdoc ISignatureQueue
    function nonces(address account) public view returns (uint256) {
        return _signatureQueueStorage().nonces[account];
    }

    /// @inheritdoc ISignatureQueue
    function hashOrder(Order calldata order) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.orderId,
                    order.queue,
                    order.asset,
                    order.caller,
                    order.recipient,
                    order.ordered,
                    order.requested,
                    order.deadline,
                    order.nonce
                )
            )
        );
    }

    /// @inheritdoc ISignatureQueue
    function validateOrder(Order calldata order, IConsensus.Signature[] calldata signatures) public view {
        if (order.deadline < block.timestamp) {
            revert OrderExpired(order.deadline);
        }
        if (order.queue != address(this)) {
            revert InvalidQueue(order.queue);
        }
        if (order.ordered == 0 || order.requested == 0) {
            revert ZeroValue();
        }
        if (order.asset != asset()) {
            revert InvalidAsset(order.asset);
        }
        if (order.caller != _msgSender()) {
            revert InvalidCaller(order.caller);
        }
        if (order.nonce != nonces(order.caller)) {
            revert InvalidNonce(order.caller, order.nonce);
        }

        consensus().requireValidSignatures(hashOrder(order), signatures);

        IShareModule shareModule_ = IShareModule(vault());
        IOracle oracle_ = shareModule_.oracle();
        if (address(oracle_) != address(0)) {
            uint256 priceD18;
            if (shareModule_.isDepositQueue(address(this))) {
                priceD18 = Math.mulDiv(order.requested, 1 ether, order.ordered);
            } else {
                priceD18 = Math.mulDiv(order.ordered, 1 ether, order.requested, Math.Rounding.Ceil);
            }
            (bool isValid, bool isSuspicious) = oracle_.validatePrice(priceD18, order.asset);
            if (!isValid || isSuspicious) {
                revert InvalidPrice();
            }
        }
    }

    /// @inheritdoc ISignatureQueue
    function canBeRemoved() external pure returns (bool) {
        return true;
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata initData) external initializer {
        SignatureQueueStorage storage $ = _signatureQueueStorage();
        bytes memory data;
        ($.asset, $.vault, data) = abi.decode(initData, (address, address, bytes));
        (address consensus_, string memory name_, string memory version_) = abi.decode(data, (address, string, string));
        if (!consensusFactory.isEntity(consensus_)) {
            revert NotEntity();
        }
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);
        $.consensus = consensus_;
        emit Initialized(initData);
    }

    // Internal functions

    function _signatureQueueStorage() internal view returns (SignatureQueueStorage storage $) {
        bytes32 slot = _signatureQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
