// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";

import {ProofLibrary} from "../ProofLibrary.sol";
import {ICowswapSettlement} from "../interfaces/ICowswapSettlement.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {BitmaskVerifier, Call, IVerifier} from "../interfaces/Imports.sol";

library WethLibrary {
    struct Info {
        address curator;
        address weth;
    }

    function getWethDepositProof(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload memory)
    {
        return ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.weth,
            0,
            abi.encodeCall(IWETH.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(IWETH.deposit, ()))
        );
    }

    function getWethDepositDescription(Info memory $) internal pure returns (string memory) {
        return JsonLibrary.toJson(
            "WETH.deposit{value: any}()",
            ABILibrary.getABI(IWETH.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.weth), "any"),
            new ParameterLibrary.Parameter[](0)
        );
    }

    function getWethDepositCalls(Info memory $) internal pure returns (Call[] memory calls) {
        calls = new Call[](5);
        calls[0] = Call($.curator, $.weth, 1 ether, abi.encodeCall(IWETH.deposit, ()), true);
        calls[1] = Call($.curator, $.weth, 0, abi.encodeCall(IWETH.deposit, ()), true);
        calls[2] = Call(address(0xdead), $.weth, 1 ether, abi.encodeCall(IWETH.deposit, ()), false);
        calls[3] = Call($.curator, address(0xdead), 1 ether, abi.encodeCall(IWETH.deposit, ()), false);
        calls[4] = Call($.curator, $.weth, 1 ether, abi.encodePacked(IWETH.deposit.selector, uint256(0)), false);
    }

    function getWethWithdrawProof(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload memory leave)
    {
        return ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.weth,
            0,
            abi.encodeCall(IWETH.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IWETH.withdraw, (0)))
        );
    }

    function getWethWithdrawDescription(Info memory $) internal pure returns (string memory) {
        return JsonLibrary.toJson(
            "WETH.withdraw(any)",
            ABILibrary.getABI(IWETH.withdraw.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.weth), "0"),
            ParameterLibrary.buildAny("wad")
        );
    }

    function getWethWithdrawCalls(Info memory $) internal pure returns (Call[] memory calls) {
        calls = new Call[](6);
        calls[0] = Call($.curator, $.weth, 0, abi.encodeCall(IWETH.withdraw, (0)), true);
        calls[1] = Call($.curator, $.weth, 0, abi.encodeCall(IWETH.withdraw, (type(uint256).max)), true);
        calls[2] = Call(address(0xdead), $.weth, 0, abi.encodeCall(IWETH.withdraw, (0)), false);
        calls[3] = Call($.curator, address(0xdead), 0, abi.encodeCall(IWETH.withdraw, (0)), false);
        calls[4] = Call($.curator, $.weth, 0, abi.encodePacked(IWETH.withdraw.selector), false);
        calls[5] = Call($.curator, $.weth, 1 ether, abi.encodeCall(IWETH.withdraw, (0)), false);
    }

    function getWethProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](2);
        leaves[0] = getWethDepositProof(bitmaskVerifier, $);
        leaves[1] = getWethWithdrawProof(bitmaskVerifier, $);
    }

    function getWethDescriptions(Info memory $) internal pure returns (string[] memory descriptions) {
        descriptions = new string[](2);
        descriptions[0] = getWethDepositDescription($);
        descriptions[1] = getWethWithdrawDescription($);
    }

    function getWethCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        calls = new Call[][](2);
        calls[0] = getWethDepositCalls($);
        calls[1] = getWethWithdrawCalls($);
    }
}
