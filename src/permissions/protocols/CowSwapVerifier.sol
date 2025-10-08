// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {GPv2Settlement, GPv2Signing} from "@cowswap/contracts/GPv2Settlement.sol";
import {GPv2Order} from "@cowswap/contracts/libraries/GPv2Order.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {OwnedCustomVerifier, SlotLibrary} from "./OwnedCustomVerifier.sol";

contract CowSwapVerifier is OwnedCustomVerifier {
    error Forbidden(string reason);

    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct CowSwapVerifierStorage {
        EnumerableSet.Bytes32Set orderUidHashes;
    }

    bytes32 public constant ASSET_ROLE = keccak256("permissions.protocols.CowSwapVerifier.ASSET_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.CowSwapVerifier.CALLER_ROLE");
    bytes32 public constant SET_ORDER_STATUS_ROLE =
        keccak256("permissions.protocols.CowSwapVerifier.SET_ORDER_STATUS_ROLE");
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
        return orderUid.length == GPv2Order.UID_LENGTH
            && _cowSwapVerifierStorage().orderUidHashes.contains(keccak256(orderUid));
    }

    function orderUidHashAt(uint256 index) public view returns (bytes32) {
        return _cowSwapVerifierStorage().orderUidHashes.at(index);
    }

    function orderUidHashesLength() public view returns (uint256) {
        return _cowSwapVerifierStorage().orderUidHashes.length();
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (value != 0 || !hasRole(CALLER_ROLE, who) || where != address(cowSwapSettlement) || callData.length < 4) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        bytes memory orderUid;
        if (selector == GPv2Signing.setPreSignature.selector) {
            (orderUid,) = abi.decode(callData[4:], (bytes, bool));
            uint32 validTo;
            assembly {
                validTo := mload(add(orderUid, 56))
            }
            if (validTo < block.timestamp) {
                return false;
            }
        } else if (selector == GPv2Settlement.invalidateOrder.selector) {
            orderUid = abi.decode(callData[4:], (bytes));
        } else {
            return false;
        }
        return hasOrderUid(orderUid);
    }

    // Mutable functions

    function setOrderStatus(GPv2Order.Data calldata order, address owner, uint32 validTo, bool allow)
        external
        onlyRole(SET_ORDER_STATUS_ROLE)
    {
        bytes32 orderDigest = GPv2Order.hash(order, cowSwapSettlement.domainSeparator());
        bytes memory orderUid = new bytes(GPv2Order.UID_LENGTH);
        GPv2Order.packOrderUidParams(orderUid, orderDigest, owner, validTo);
        bytes32 orderHash = keccak256(orderUid);
        if (allow) {
            if (!hasRole(VAULT_ROLE, owner)) {
                revert Forbidden("owner");
            }
            if (validTo < block.timestamp) {
                revert Forbidden("validTo < now");
            }
            if (validTo > block.timestamp + MAX_DEADLINE_TIMESPAN) {
                revert Forbidden("validTo > now + MAX_DEADLINE_TIMESPAN");
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
                revert Forbidden("validTo mismatch");
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
            if (!_cowSwapVerifierStorage().orderUidHashes.add(orderHash)) {
                revert Forbidden("orderUid exists");
            }
        } else {
            if (!_cowSwapVerifierStorage().orderUidHashes.remove(orderHash)) {
                revert Forbidden("orderUid not found");
            }
        }

        emit OrderStatusSet(order, owner, validTo, allow);
    }

    // Internal functions

    function _cowSwapVerifierStorage() private view returns (CowSwapVerifierStorage storage $) {
        bytes32 slot = _cowSwapVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }

    event OrderStatusSet(GPv2Order.Data order, address owner, uint32 validTo, bool allow);
}
