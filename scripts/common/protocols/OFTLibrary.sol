// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import "../ProofLibrary.sol";

import {IOFT, MessagingFee, SendParam} from "../interfaces/IOFT.sol";
import "../interfaces/Imports.sol";

library OFTLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct SendInfo {
        address curator;
        address oft;
        address token;
        uint32 dstEid;
        address to;
        bytes extraOptions; // leave empty to allow any
        address refundAddress;
        bool enforceZeroLzTokenFee; // when true, requires lzTokenFee == 0
    }

    function validateOFT(address oft, address expectedToken) private view returns (string memory symbol) {
        // Ensure IOFT responds and has a non-zero token
        try IOFT(oft).oftVersion() returns (bytes4, uint64) {}
        catch {
            revert("OFTLibrary: oftVersion failed");
        }
        address actualToken;
        try IOFT(oft).token() returns (address t) {
            actualToken = t;
        } catch {
            revert("OFTLibrary: token() failed");
        }
        require(actualToken != address(0), "OFTLibrary: token is zero");
        require(actualToken == expectedToken, "OFTLibrary: token mismatch");
        
        // Get token symbol
        try IERC20Metadata(expectedToken).symbol() returns (string memory s) {
            symbol = s;
        } catch {
            revert("OFTLibrary: symbol() failed");
        }
    }

    function getApproveProof(BitmaskVerifier bitmaskVerifier, SendInfo memory $)
        internal
        view
        returns (IVerifier.VerificationPayload memory)
    {
        require($.oft != $.token, "OFTLibrary: oft must be adapter, not token");
        validateOFT($.oft, $.token);
        return ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.token,
            0,
            abi.encodeCall(IERC20.approve, ($.oft, 0)),
            ProofLibrary.makeBitmask(
                true, // who can vary in runtime
                true, // where is bound via equality in data hashing
                true, // value not used
                true, // selector
                abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
    }

    function getApproveDescription(SendInfo memory $) internal view returns (string memory desc) {
        require($.oft != $.token, "OFTLibrary: oft must be adapter, not token");
        string memory symbol = validateOFT($.oft, $.token);
        ParameterLibrary.Parameter[] memory inner =
            ParameterLibrary.build("to", Strings.toHexString($.oft)).addAny("amount");
        desc = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "IERC20(",
                    symbol,
                    ").approve(",
                    symbol,
                    "_OFTAdapter, anyInt)"
                )
            ),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.token), "0"),
            inner
        );
    }

    function getApproveCalls(SendInfo memory $) internal pure returns (Call[] memory calls) {
        require($.oft != $.token, "OFTLibrary: oft must be adapter, not token");
        Call[] memory tmp = new Call[](16);
        uint256 i = 0;
        tmp[i++] = Call($.curator, $.token, 0, abi.encodeCall(IERC20.approve, ($.oft, 0)), true);
        tmp[i++] = Call($.curator, $.token, 0, abi.encodeCall(IERC20.approve, ($.oft, 1 ether)), true);
        tmp[i++] = Call(address(0xdead), $.token, 0, abi.encodeCall(IERC20.approve, ($.oft, 1 ether)), false);
        tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.oft, 1 ether)), false);
        tmp[i++] = Call($.curator, $.token, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 1 ether)), false);
        tmp[i++] = Call($.curator, $.token, 1 wei, abi.encodeCall(IERC20.approve, ($.oft, 1 ether)), false);
        tmp[i++] = Call($.curator, $.token, 0, abi.encode(IERC20.approve.selector, $.oft, 1 ether), false);
        assembly {
            mstore(tmp, i)
        }
        return tmp;
    }

    function getSendProof(BitmaskVerifier bitmaskVerifier, SendInfo memory $)
        internal
        view
        returns (IVerifier.VerificationPayload memory)
    {
        validateOFT($.oft, $.token);
        // data with strict fields set, amount/minAmount left at 0 (ignored by mask)
        bytes memory data = abi.encodeCall(
            IOFT.send,
            (
                SendParam({
                    dstEid: $.dstEid,
                    to: bytes32(uint256(uint160($.to))),
                    amountLD: 0,
                    minAmountLD: 0,
                    extraOptions: $.extraOptions,
                    composeMsg: new bytes(0),
                    oftCmd: new bytes(0)
                }),
                MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                $.refundAddress
            )
        );

        // mask: lock dstEid, to, (optionally) lzTokenFee==0, refundAddress; allow amounts and dynamic bytes unless provided
        bytes memory mask = abi.encodeCall(
            IOFT.send,
            (
                SendParam({
                    dstEid: type(uint32).max, // check dst
                    to: bytes32(type(uint256).max), // check receiver
                    amountLD: 0, // allow any
                    minAmountLD: 0, // allow any
                    extraOptions: $.extraOptions, // if non-empty will be enforced byte-for-byte; if empty, not enforced
                    composeMsg: new bytes(0),
                    oftCmd: new bytes(0)
                }),
                MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? type(uint256).max : 0}),
                address(type(uint160).max) // check refund
            )
        );

        return ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.oft,
            0, // value is not constrained by mask; runtime value may be non-zero
            data,
            ProofLibrary.makeBitmask(true, true, false, true, mask)
        );
    }

    function _buildSendInnerParams(SendInfo memory $) private pure returns (ParameterLibrary.Parameter[] memory) {
        ParameterLibrary.Parameter[] memory inner = ParameterLibrary.build("dstEid", Strings.toString($.dstEid));
        
        inner = inner.add("to", Strings.toHexString($.to));
        inner = inner.add("amountLD", "any");
        inner = inner.add("minAmountLD", "any");
        inner = inner.add(
            "extraOptions", $.extraOptions.length == 0 ? "any" : Strings.toHexString(uint256(bytes32($.extraOptions)))
        );
        inner = inner.add("composeMsg", "0x");
        inner = inner.add("oftCmd", "0x");
        inner = inner.add("nativeFee", "any");
        inner = inner.add("lzTokenFee", $.enforceZeroLzTokenFee ? "0" : "any");
        inner = inner.add("_refundAddress", Strings.toHexString($.refundAddress));
        
        return inner;
    }

    function _buildSendTitle(SendInfo memory $, string memory contractName) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                contractName,
                ".send(dstEid=",
                Strings.toString($.dstEid),
                ", to=",
                Strings.toHexString($.to),
                ", extraOptions=",
                ($.extraOptions.length == 0 ? "any" : Strings.toHexString(uint256(bytes32($.extraOptions)))),
                ")"
            )
        );
    }

    function getSendDescription(SendInfo memory $) internal view returns (string memory desc) {
        string memory symbol = validateOFT($.oft, $.token);
        string memory contractName = $.oft == $.token
            ? string(abi.encodePacked(symbol, "_OFT"))
            : string(abi.encodePacked(symbol, "_OFTAdapter"));
        
        desc = JsonLibrary.toJson(
            _buildSendTitle($, contractName),
            ABILibrary.getABI(IOFT.send.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.oft), "any"),
            _buildSendInnerParams($)
        );
    }

    function getSendCalls(SendInfo memory $) internal pure returns (Call[] memory calls) {
        Call[] memory tmp = new Call[](16);
        uint256 i = 0;
        // valid minimal (fee 0, value 0)
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: $.dstEid,
                        to: bytes32(uint256(uint160($.to))),
                        amountLD: 0,
                        minAmountLD: 0,
                        extraOptions: $.extraOptions,
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                    $.refundAddress
                )
            ),
            true
        );
        // valid with nonzero nativeFee but msg.value still 0 (mask ignores value)
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: $.dstEid,
                        to: bytes32(uint256(uint160($.to))),
                        amountLD: 1,
                        minAmountLD: 1,
                        extraOptions: $.extraOptions,
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    MessagingFee({nativeFee: 1, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                    $.refundAddress
                )
            ),
            true
        );
        // wrong who
        tmp[i++] = Call(address(0xdead), $.oft, 0, tmp[0].data, false);
        // wrong where
        tmp[i++] = Call($.curator, address(0xdead), 0, tmp[0].data, false);
        // wrong dstEid
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: $.dstEid + 1,
                        to: bytes32(uint256(uint160($.to))),
                        amountLD: 0,
                        minAmountLD: 0,
                        extraOptions: $.extraOptions,
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                    $.refundAddress
                )
            ),
            false
        );
        // wrong to
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: $.dstEid,
                        to: bytes32(uint256(uint160(address(0xdead)))),
                        amountLD: 0,
                        minAmountLD: 0,
                        extraOptions: $.extraOptions,
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                    $.refundAddress
                )
            ),
            false
        );
        // wrong refund address
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: $.dstEid,
                        to: bytes32(uint256(uint160($.to))),
                        amountLD: 0,
                        minAmountLD: 0,
                        extraOptions: $.extraOptions,
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                    address(0xdead)
                )
            ),
            false
        );
        // selector-encoded variant
        tmp[i++] = Call(
            $.curator,
            $.oft,
            0,
            abi.encode(
                IOFT.send.selector,
                SendParam({
                    dstEid: $.dstEid,
                    to: bytes32(uint256(uint160($.to))),
                    amountLD: 0,
                    minAmountLD: 0,
                    extraOptions: $.extraOptions,
                    composeMsg: new bytes(0),
                    oftCmd: new bytes(0)
                }),
                MessagingFee({nativeFee: 0, lzTokenFee: $.enforceZeroLzTokenFee ? 0 : 0}),
                $.refundAddress
            ),
            false
        );
        assembly {
            mstore(tmp, i)
        }
        return tmp;
    }
}
