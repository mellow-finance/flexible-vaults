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

    bytes32 private immutable _signatureQueueStorageSlot;
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 orderId,address queue,address asset,address caller,address recipient,uint256 ordered,uint256 requested,uint256 deadline,uint256 nonce)"
    );

    constructor(string memory name_, uint256 version_) {
        _signatureQueueStorageSlot = SlotLibrary.getSlot("SignatureQueue", name_, version_);
        _disableInitializers();
    }

    // View functions

    function claimableOf(address /* account */ ) public view virtual returns (uint256) {
        return 0;
    }

    function claim(address /* account */ ) external virtual returns (uint256) {
        return 0;
    }

    function shareModule() public view returns (IShareModule) {
        return IShareModule(_signatureQueueStorage().vault);
    }

    function asset() public view returns (address) {
        return _signatureQueueStorage().asset;
    }

    function vault() public view returns (address) {
        return _signatureQueueStorage().vault;
    }

    function oracle() public view virtual returns (IOracle);

    function consensus() public view returns (IConsensus) {
        return IConsensus(_signatureQueueStorage().consensus);
    }

    function nonces(address account) public view returns (uint256) {
        return _signatureQueueStorage().nonces[account];
    }

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

    function validateOrder(Order calldata order, IConsensus.Signature[] calldata signatures) public view {
        if (order.deadline < block.timestamp) {
            revert("SignatureQueue: order expired");
        }
        if (order.queue != address(this)) {
            revert("SignatureQueue: invalid queue");
        }
        if (order.ordered == 0) {
            revert("SignatureQueue: zero ordered value");
        }
        if (order.requested == 0) {
            revert("SignatureQueue: zero requested value");
        }
        if (order.asset != asset()) {
            revert("SignatureQueue: invalid asset");
        }
        if (order.caller != _msgSender()) {
            revert("SignatureQueue: invalid caller");
        }
        if (order.nonce != nonces(order.caller)) {
            revert("SignatureQueue: invalid nonce");
        }

        consensus().requireValidSignatures(hashOrder(order), signatures);

        IOracle oracle_ = oracle();

        if (address(oracle_) != address(0)) {
            uint256 priceD18 = Math.mulDiv(order.requested, 1 ether, order.ordered);
            (bool isValid, bool isSuspicious) = oracle_.validatePrice(priceD18, oracle_.getReport(order.asset).priceD18);
            if (!isValid) {
                revert("SignatureQueue: invalid price");
            }
            if (isSuspicious) {
                revert("SignatureQueue: suspicious price");
            }
        }
    }

    // Mutable functions

    function initialize(bytes calldata initData) external initializer {
        SignatureQueueStorage storage $ = _signatureQueueStorage();
        bytes memory data;
        ($.asset, $.vault, data) = abi.decode(initData, (address, address, bytes));
        (address consensus_, string memory name_, string memory version_) = abi.decode(data, (address, string, string));
        if (consensus_ == address(0)) {
            revert("SignatureQueue: consensus address cannot be zero");
        }
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);
        $.consensus = consensus_;
    }

    function handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) external {}

    // Internal functions

    function _signatureQueueStorage() internal view returns (SignatureQueueStorage storage dqs) {
        bytes32 slot = _signatureQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }
}
