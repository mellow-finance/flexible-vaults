// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/modules/ISharesModule.sol";
import "../interfaces/permissions/IConsensus.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

contract SignatureDepositQueue is EIP712Upgradeable, ReentrancyGuardUpgradeable, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    enum SignatureType {
        EIP712,
        EIP1271
    }

    struct SignatureDepositQueueStorage {
        address consensus;
        address vault;
        address asset;
        EnumerableSet.AddressSet whitelist;
        mapping(address account => uint256 nonce) nonces;
    }

    struct Order {
        uint256 orderId;
        address asset;
        address caller;
        address recipient;
        uint256 value;
        uint256 shares;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 private immutable _signatureDepositQueueStorageSlot;
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 orderId,address asset,address caller,address recipient,uint256 value,uint256 shares,uint256 deadline,uint256 nonce)"
    );

    constructor(string memory name_, uint256 version_) {
        _disableInitializers();
        _signatureDepositQueueStorageSlot = SlotLibrary.getSlot("SignatureDepositQueue", name_, version_);
    }

    // View functions

    function sharesModule() public view returns (ISharesModule) {
        SignatureDepositQueueStorage storage $ = _signatureDepositQueueStorage();
        return ISharesModule($.vault);
    }

    function asset() public view returns (address) {
        SignatureDepositQueueStorage storage $ = _signatureDepositQueueStorage();
        return $.asset;
    }

    function hashOrder(Order calldata order) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.orderId,
                    order.asset,
                    order.caller,
                    order.recipient,
                    order.value,
                    order.shares,
                    order.deadline,
                    order.nonce
                )
            )
        );
    }

    function consensus() public view returns (IConsensus) {
        SignatureDepositQueueStorage storage $ = _signatureDepositQueueStorage();
        return IConsensus($.consensus);
    }

    function nonces(address account) public view returns (uint256) {
        SignatureDepositQueueStorage storage $ = _signatureDepositQueueStorage();
        return $.nonces[account];
    }

    function isWhitelisted(address account) public view returns (bool) {
        SignatureDepositQueueStorage storage $ = _signatureDepositQueueStorage();
        return $.whitelist.contains(account);
    }

    function validateOrder(Order calldata order, IConsensus.Signature[] calldata signatures) public view {
        if (order.deadline < block.timestamp) {
            revert("SignatureDepositQueue: order expired");
        }
        if (order.value == 0) {
            revert("SignatureDepositQueue: zero value");
        }
        if (order.shares == 0) {
            revert("SignatureDepositQueue: zero shares");
        }
        if (order.asset != asset()) {
            revert("SignatureDepositQueue: invalid asset");
        }
        if (order.caller != _msgSender()) {
            revert("SignatureDepositQueue: invalid caller");
        }
        if (order.nonce != nonces(order.caller)) {
            revert("SignatureDepositQueue: invalid nonce");
        }
        if (!isWhitelisted(order.caller)) {
            revert("SignatureDepositQueue: recipient not whitelisted");
        }

        consensus().requireValidSignatures(hashOrder(order), signatures);

        IOracle depositOracle = sharesModule().depositOracle();
        if (address(depositOracle) != address(0)) {
            (bool isValid, bool isSuspicious) =
                depositOracle.validatePrice(order.value, depositOracle.getReport(order.asset).priceD18);
            if (!isValid) {
                revert("SignatureDepositQueue: invalid price");
            }
            if (isSuspicious) {
                revert("SignatureDepositQueue: suspicious price");
            }
        }
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (string memory name_, string memory version_) = abi.decode(data, (string, string));
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);
    }

    function deposit(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureDepositQueueStorage().nonces[order.caller]++;
        TransferLibrary.receiveAssets(order.asset, order.caller, order.value);
        sharesModule().sharesManager().mint(order.recipient, order.shares);
    }

    // Internal functions

    function _signatureDepositQueueStorage() internal view returns (SignatureDepositQueueStorage storage dqs) {
        bytes32 slot = _signatureDepositQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }
}
