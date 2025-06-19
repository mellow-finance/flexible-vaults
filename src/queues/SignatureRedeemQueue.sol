// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/modules/IRedeemModule.sol";
import "../interfaces/modules/ISharesModule.sol";
import "../interfaces/permissions/IConsensus.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

contract SignatureRedeemQueue is EIP712Upgradeable, ReentrancyGuardUpgradeable, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    enum SignatureType {
        EIP712,
        EIP1271
    }

    struct SignatureRedeemQueueStorage {
        address consensus;
        address vault;
        address asset;
        EnumerableSet.AddressSet whitelist;
        mapping(address account => uint256 nonce) nonces;
    }

    struct RedeemOrder {
        uint256 orderId;
        address asset;
        address caller;
        address recipient;
        uint256 value;
        uint256 assets;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 private immutable _signatureRedeemQueueStorageSlot;
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "RedeemOrder(uint256 orderId,address asset,address caller,address recipient,uint256 value,uint256 assets,uint256 deadline,uint256 nonce)"
    );

    constructor(string memory name_, uint256 version_) {
        _disableInitializers();
        _signatureRedeemQueueStorageSlot = SlotLibrary.getSlot("SignatureRedeemQueue", name_, version_);
    }

    // View functions

    function sharesModule() public view returns (ISharesModule) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return ISharesModule($.vault);
    }

    function asset() public view returns (address) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return $.asset;
    }

    function vault() public view returns (address) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return $.vault;
    }

    function hashOrder(RedeemOrder calldata order) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.orderId,
                    order.asset,
                    order.caller,
                    order.recipient,
                    order.value,
                    order.assets,
                    order.deadline,
                    order.nonce
                )
            )
        );
    }

    function consensus() public view returns (IConsensus) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return IConsensus($.consensus);
    }

    function nonces(address account) public view returns (uint256) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return $.nonces[account];
    }

    function isWhitelisted(address account) public view returns (bool) {
        SignatureRedeemQueueStorage storage $ = _signatureRedeemQueueStorage();
        return $.whitelist.contains(account);
    }

    function validateOrder(RedeemOrder calldata order, IConsensus.Signature[] calldata signatures) public view {
        if (order.deadline < block.timestamp) {
            revert("SignatureRedeemQueue: order expired");
        }
        if (order.value == 0) {
            revert("SignatureRedeemQueue: zero value");
        }
        if (order.assets == 0) {
            revert("SignatureRedeemQueue: zero assets");
        }
        if (order.asset != asset()) {
            revert("SignatureRedeemQueue: invalid asset");
        }
        if (order.caller != _msgSender()) {
            revert("SignatureRedeemQueue: invalid caller");
        }
        if (order.nonce != nonces(order.caller)) {
            revert("SignatureRedeemQueue: invalid nonce");
        }
        if (!isWhitelisted(order.caller)) {
            revert("SignatureRedeemQueue: recipient not whitelisted");
        }

        consensus().requireValidSignatures(hashOrder(order), signatures);

        IOracle redeemOracle = sharesModule().redeemOracle();
        if (address(redeemOracle) != address(0)) {
            uint256 priceD18 = Math.mulDiv(order.assets, 1 ether, order.value);
            (bool isValid, bool isSuspicious) =
                redeemOracle.validatePrice(priceD18, redeemOracle.getReport(order.asset).priceD18);
            if (!isValid) {
                revert("SignatureRedeemQueue: invalid price");
            }
            if (isSuspicious) {
                revert("SignatureRedeemQueue: suspicious price");
            }
        }
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (string memory name_, string memory version_) = abi.decode(data, (string, string));
        __ReentrancyGuard_init();
        __EIP712_init(name_, version_);
    }

    function redeem(RedeemOrder calldata order, IConsensus.Signature[] calldata signatures)
        external
        payable
        nonReentrant
    {
        validateOrder(order, signatures);
        IRedeemModule vault_ = IRedeemModule(vault());
        if (vault_.getLiquidAssets(order.asset) < order.assets) {
            revert("SignatureRedeemQueue: insufficient liquid assets");
        }
        _signatureRedeemQueueStorage().nonces[order.caller]++;
        sharesModule().sharesManager().burn(order.recipient, order.value);
        vault_.callRedeemHook(order.asset, order.assets);
        TransferLibrary.sendAssets(order.asset, order.recipient, order.assets);
    }

    // Internal functions

    function _signatureRedeemQueueStorage() internal view returns (SignatureRedeemQueueStorage storage dqs) {
        bytes32 slot = _signatureRedeemQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }
}
