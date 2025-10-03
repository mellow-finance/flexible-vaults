// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {GPv2Settlement, GPv2Signing} from "@cowswap/contracts/GPv2Settlement.sol";
import {GPv2Order} from "@cowswap/contracts/libraries/GPv2Order.sol";

import "./OwnedCustomVerifier.sol";

contract CowSwapVerifier is OwnedCustomVerifier {
    error Forbidden(string reason);

    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct CowSwapVerifierStorage {
        bytes[] orderUids;
        mapping(bytes => uint256) indices;
    }

    bytes32 public constant ASSET_ROLE = keccak256("permissions.protocols.CowSwapVerifier.ASSET_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.CowSwapVerifier.CALLER_ROLE");
    bytes32 public constant SET_ORDER_STATUS = keccak256("permissions.protocols.CowSwapVerifier.SET_ORDER_STATUS");
    bytes32 public constant VAULT_ROLE = keccak256("permissions.protocols.CowSwapVerifier.VAULT_ROLE");

    uint32 public constant MAX_DEADLINE_TIMESPAN = 24 hours;

    GPv2Settlement public immutable cowSwapSettlement;

    bytes32 private immutable _cowSwapVerifierStorageSlot;

    constructor(address cowSwapSettlement_, string memory name_, uint256 version_)
        OwnedCustomVerifier(name_, version_)
    {
        cowSwapSettlement = GPv2Settlement(payable(cowSwapSettlement_));
        _cowSwapVerifierStorageSlot = SlotLibrary.getSlot("CowSwapVerifier", name_, version_);
    }

    // View functions

    function hasOrderUid(bytes memory orderUid) public view returns (bool) {
        return _cowSwapVerifierStorage().indices[orderUid] != 0;
    }

    function orderUidAt(uint256 index) public view returns (bytes memory) {
        return _cowSwapVerifierStorage().orderUids[index];
    }

    function orderUids() public view returns (uint256) {
        return _cowSwapVerifierStorage().orderUids.length;
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (callData.length < 4 || value != 0 || !hasRole(CALLER_ROLE, who) || where != address(cowSwapSettlement)) {
            return false;
        }
        if (GPv2Signing.setPreSignature.selector == bytes4(callData[:4])) {
            if (callData.length != 0xa4) {
                return false;
            }
            bool flag = bytes32(callData[0x24:0x44]) != bytes32(0);
            bytes calldata orderUid = callData[0x64:0x9c];
            if (!hasOrderUid(orderUid)) {
                return false;
            }
            (,, uint32 validTo) = GPv2Order.extractOrderUidParams(orderUid);
            if (validTo < block.timestamp) {
                return false;
            }
            if (keccak256(callData) != keccak256(abi.encodeCall(GPv2Signing.setPreSignature, (orderUid, flag)))) {
                return false;
            }
        } else if (GPv2Settlement.invalidateOrder.selector == bytes4(callData[:4])) {
            return callData.length == 0x84;
        } else {
            return false;
        }

        return true;
    }

    // Mutable functions

    function setOrderStatus(GPv2Order.Data calldata order, address owner, uint32 validTo, bool allow)
        external
        onlyRole(SET_ORDER_STATUS)
    {
        bytes32 orderDigest = GPv2Order.hash(order, cowSwapSettlement.domainSeparator());
        bytes memory orderUid = new bytes(56);
        GPv2Order.packOrderUidParams(orderUid, orderDigest, owner, validTo);
        CowSwapVerifierStorage storage $ = _cowSwapVerifierStorage();
        bytes[] storage orderUids = $.orderUids;
        if (allow) {
            if ($.indices[orderUid] != 0) {
                revert Forbidden("orderUid already exists");
            }
            if (!hasRole(VAULT_ROLE, owner)) {
                revert Forbidden("owner");
            }
            if (validTo < block.timestamp) {
                revert Forbidden("validTo < block.timestamp");
            }
            if (!hasRole(ASSET_ROLE, address(order.sellToken))) {
                revert Forbidden("sellToken");
            }
            if (!hasRole(ASSET_ROLE, address(order.buyToken))) {
                revert Forbidden("buyToken");
            }
            if (order.receiver != address(0)) {
                revert Forbidden("receiver != 0");
            }
            if (order.validTo != validTo) {
                revert Forbidden("order.validTo != validTo");
            }
            if (order.appData != bytes32(0)) {
                revert Forbidden("appData != 0");
            }
            if (order.kind != GPv2Order.KIND_SELL) {
                revert Forbidden("kind != GPv2Order.KIND_SELL");
            }
            if (order.sellTokenBalance != GPv2Order.BALANCE_ERC20) {
                revert Forbidden("sellTokenBalance != GPv2Order.BALANCE_ERC20");
            }
            if (order.buyTokenBalance != GPv2Order.BALANCE_ERC20) {
                revert Forbidden("buyTokenBalance != GPv2Order.BALANCE_ERC20");
            }
            orderUids.push(orderUid);
            $.indices[orderUid] = orderUids.length;
        } else {
            uint256 index = $.indices[orderUid];
            if (index == 0) {
                revert Forbidden("orderUid not found");
            }
            uint256 length = orderUids.length;
            orderUids[index - 1] = orderUids[length - 1];
            orderUids.pop();
        }
    }

    // Internal functions

    function _cowSwapVerifierStorage() private view returns (CowSwapVerifierStorage storage $) {
        bytes32 slot = _cowSwapVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
