// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ABILibrary} from "../ABILibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {BitmaskVerifier, Call, IVerifier} from "../interfaces/Imports.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEtherFiLiquidityPool, IWEETH, IWithdrawRequestNFT} from "../interfaces/IEtherfi.sol";

library EtherfiLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address eETH;
        address weETH;
        address liquidityPool;
        address withdrawRequestNFT;
        address recipient; // expected recipient for requestWithdraw (subvault0)
    }

    function getProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        // 1) eETH.approve(weETH, any)
        // 2) weETH.unwrap(any)
        // 3) LiquidityPool.requestWithdraw(subvault0, any)
        // 4) WithdrawRequestNFT.claimWithdraw(any)
        leaves = new IVerifier.VerificationPayload[](4);

        leaves[0] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.eETH,
            0,
            abi.encodeCall(IERC20.approve, ($.weETH, 0)),
            // spender must match, amount is wildcard
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );

        leaves[1] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.weETH,
            0,
            abi.encodeCall(IWEETH.unwrap, (0)),
            // selector pinned; amount wildcard; value pinned to 0
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IWEETH.unwrap, (0)))
        );

        leaves[2] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.liquidityPool,
            0,
            abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 0)),
            // recipient must match subvault, amount wildcard
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, (address(type(uint160).max), 0))
            )
        );

        leaves[3] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.withdrawRequestNFT,
            0,
            abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)),
            // requestId wildcard, value pinned to 0
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)))
        );
    }

    function getDescriptions(Info memory $) internal pure returns (string[] memory descriptions) {
        descriptions = new string[](4);

        // eETH.approve(weETH, any)
        {
            ParameterLibrary.Parameter[] memory innerParams =
                ParameterLibrary.build("to", Strings.toHexString($.weETH)).addAny("amount");
            descriptions[0] = JsonLibrary.toJson(
                string(abi.encodePacked("eETH.approve(weETH, any)")),
                ABILibrary.getABI(IERC20.approve.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.eETH), "0"),
                innerParams
            );
        }

        // weETH.unwrap(any)
        {
            ParameterLibrary.Parameter[] memory innerParams = ParameterLibrary.buildAny("weETHAmount");
            descriptions[1] = JsonLibrary.toJson(
                string(abi.encodePacked("weETH.unwrap(any)")),
                ABILibrary.getABI(IWEETH.unwrap.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.weETH), "0"),
                innerParams
            );
        }

        // LiquidityPool.requestWithdraw(subvault0, any)
        {
            ParameterLibrary.Parameter[] memory innerParams = ParameterLibrary.build(
                "recipient",
                Strings.toHexString($.recipient)
            ).addAny("amount");
            descriptions[2] = JsonLibrary.toJson(
                string(abi.encodePacked("EtherFiLiquidityPool.requestWithdraw(subvault0, any)")),
                ABILibrary.getABI(IEtherFiLiquidityPool.requestWithdraw.selector),
                ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.liquidityPool), "0"),
                innerParams
            );
        }

        // WithdrawRequestNFT.claimWithdraw(any)
        {
            ParameterLibrary.Parameter[] memory innerParams = ParameterLibrary.buildAny("requestId");
            descriptions[3] = JsonLibrary.toJson(
                string(abi.encodePacked("WithdrawRequestNFT.claimWithdraw(any)")),
                ABILibrary.getABI(IWithdrawRequestNFT.claimWithdraw.selector),
                ParameterLibrary.build(
                    Strings.toHexString($.curator), Strings.toHexString($.withdrawRequestNFT), "0"
                ),
                innerParams
            );
        }
    }

    function getCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        calls = new Call[][](4);

        // eETH.approve(weETH, any)
        {
            Call[] memory tmp = new Call[](7);
            tmp[0] = Call($.curator, $.eETH, 0, abi.encodeCall(IERC20.approve, ($.weETH, 0)), true);
            tmp[1] = Call($.curator, $.eETH, 0, abi.encodeCall(IERC20.approve, ($.weETH, 1 ether)), true);
            tmp[2] = Call(address(0xdead), $.eETH, 0, abi.encodeCall(IERC20.approve, ($.weETH, 1 ether)), false);
            tmp[3] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.weETH, 1 ether)), false);
            tmp[4] = Call($.curator, $.eETH, 1 wei, abi.encodeCall(IERC20.approve, ($.weETH, 0)), false);
            tmp[5] = Call($.curator, $.eETH, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 0)), false);
            tmp[6] = Call(
                $.curator, $.eETH, 0, abi.encode(IERC20.approve.selector, $.weETH, 0), false
            );
            calls[0] = tmp;
        }

        // weETH.unwrap(any)
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] = Call($.curator, $.weETH, 0, abi.encodeCall(IWEETH.unwrap, (0)), true);
            tmp[1] = Call($.curator, $.weETH, 0, abi.encodeCall(IWEETH.unwrap, (type(uint256).max)), true);
            tmp[2] = Call(address(0xdead), $.weETH, 0, abi.encodeCall(IWEETH.unwrap, (0)), false);
            tmp[3] = Call($.curator, address(0xdead), 0, abi.encodeCall(IWEETH.unwrap, (0)), false);
            tmp[4] = Call($.curator, $.weETH, 0, abi.encodePacked(IWEETH.unwrap.selector), false);
            tmp[5] = Call($.curator, $.weETH, 1 wei, abi.encodeCall(IWEETH.unwrap, (0)), false);
            calls[1] = tmp;
        }

        // requestWithdraw(subvault0, any)
        {
            Call[] memory tmp = new Call[](8);
            tmp[0] = Call(
                $.curator,
                $.liquidityPool,
                0,
                abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 0)),
                true
            );
            tmp[1] = Call(
                $.curator,
                $.liquidityPool,
                0,
                abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 1 ether)),
                true
            );
            tmp[2] = Call(
                address(0xdead), $.liquidityPool, 0, abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 1)), false
            );
            tmp[3] = Call(
                $.curator, address(0xdead), 0, abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 1)), false
            );
            tmp[4] = Call(
                $.curator, $.liquidityPool, 1 wei, abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 0)), false
            );
            tmp[5] = Call(
                $.curator, $.liquidityPool, 0, abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, (address(0xdead), 0)), false
            );
            tmp[6] = Call(
                $.curator,
                $.liquidityPool,
                0,
                abi.encode(IEtherFiLiquidityPool.requestWithdraw.selector, $.recipient, 0),
                false
            );
            tmp[7] = Call(
                $.curator,
                $.liquidityPool,
                0,
                abi.encodeCall(IEtherFiLiquidityPool.requestWithdraw, ($.recipient, 0)),
                true
            );
            calls[2] = tmp;
        }

        // claimWithdraw(any)
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] = Call($.curator, $.withdrawRequestNFT, 0, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)), true);
            tmp[1] = Call(
                $.curator, $.withdrawRequestNFT, 0, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (type(uint256).max)), true
            );
            tmp[2] = Call(address(0xdead), $.withdrawRequestNFT, 0, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)), false);
            tmp[3] = Call($.curator, address(0xdead), 0, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)), false);
            tmp[4] = Call($.curator, $.withdrawRequestNFT, 1 wei, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, (0)), false);
            tmp[5] = Call($.curator, $.withdrawRequestNFT, 0, abi.encodePacked(IWithdrawRequestNFT.claimWithdraw.selector), false);
            calls[3] = tmp;
        }
    }
}


