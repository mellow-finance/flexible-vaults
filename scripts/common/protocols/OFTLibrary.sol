// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/ILayerZeroOFTAdapter.sol";
import "../interfaces/Imports.sol";

import "./ERC20Library.sol";

library OFTLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        address targetSubvault;
        bool approveRequired;
        address sourceOFT;
        uint32 dstEid;
        string subvaultName;
        string targetSubvaultName;
        string targetChainName;
    }

    function getOFTProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        view
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](2);
        uint256 iterator = 0;
        if ($.approveRequired) {
            iterator = ArraysLibrary.insert(
                leaves,
                ERC20Library.getERC20Proofs(
                    bitmaskVerifier,
                    ERC20Library.Info({
                        curator: $.curator,
                        assets: ArraysLibrary.makeAddressArray(abi.encode(ILayerZeroOFTAdapter($.sourceOFT).token())),
                        to: ArraysLibrary.makeAddressArray(abi.encode($.sourceOFT))
                    })
                ),
                iterator
            );
        }
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.sourceOFT,
            0,
            abi.encodeCall(
                ILayerZeroOFT.send,
                (
                    ILayerZeroOFT.SendParam({
                        dstEid: $.dstEid,
                        to: bytes32(uint256(uint160($.targetSubvault))),
                        amountLD: 0,
                        minAmountLD: 0,
                        extraOptions: new bytes(0),
                        composeMsg: new bytes(0),
                        oftCmd: new bytes(0)
                    }),
                    ILayerZeroOFT.MessagingFee({nativeFee: 0, lzTokenFee: 0}),
                    $.subvault
                )
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam({
                            dstEid: type(uint32).max,
                            to: bytes32(type(uint256).max),
                            amountLD: 0,
                            minAmountLD: 0,
                            extraOptions: new bytes(0),
                            composeMsg: new bytes(0),
                            oftCmd: new bytes(0)
                        }),
                        ILayerZeroOFT.MessagingFee({nativeFee: 0, lzTokenFee: type(uint256).max}),
                        address(type(uint160).max)
                    )
                )
            )
        );

        assembly {
            mstore(leaves, iterator)
        }
    }

    function getOFTDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](2);
        uint256 iterator = 0;

        if ($.approveRequired) {
            iterator = ArraysLibrary.insert(
                descriptions,
                ERC20Library.getERC20Descriptions(
                    ERC20Library.Info({
                        curator: $.curator,
                        assets: ArraysLibrary.makeAddressArray(abi.encode(ILayerZeroOFTAdapter($.sourceOFT).token())),
                        to: ArraysLibrary.makeAddressArray(abi.encode($.sourceOFT))
                    })
                ),
                iterator
            );
        }

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters.addJson(
            "_sendParam",
            JsonLibrary.toJson(
                ILayerZeroOFT.SendParam({
                    dstEid: $.dstEid,
                    to: bytes32(uint256(uint160($.targetSubvault))),
                    amountLD: 0,
                    minAmountLD: 0,
                    extraOptions: new bytes(0),
                    composeMsg: new bytes(0),
                    oftCmd: new bytes(0)
                })
            )
        );

        innerParameters = innerParameters.addJson(
            "_fee", JsonLibrary.toJson(ILayerZeroOFT.MessagingFee({nativeFee: 0, lzTokenFee: type(uint256).max}))
        );
        innerParameters = innerParameters.add("_refundAddress", $.subvaultName);

        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "LayerZeroOFT.send{value: any}(targetChain=",
                    $.targetChainName,
                    ", targetSubvault=",
                    $.targetSubvaultName,
                    ")"
                )
            ),
            ABILibrary.getABI(ILayerZeroOFT.send.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.sourceOFT), "any"),
            innerParameters
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getOFTCalls(Info memory $) internal view returns (Call[][] memory calls) {
        calls = new Call[][](2);

        uint256 iterator = 0;
        if ($.approveRequired) {
            iterator = ArraysLibrary.insert(
                calls,
                ERC20Library.getERC20Calls(
                    ERC20Library.Info({
                        curator: $.curator,
                        assets: ArraysLibrary.makeAddressArray(abi.encode(ILayerZeroOFTAdapter($.sourceOFT).token())),
                        to: ArraysLibrary.makeAddressArray(abi.encode($.sourceOFT))
                    })
                ),
                iterator
            );
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            bytes32 to = bytes32(uint256(uint160($.targetSubvault)));
            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                0,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 0, 0, "", "", ""),
                        ILayerZeroOFT.MessagingFee(0, 0),
                        $.subvault
                    )
                ),
                true
            );

            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );

            tmp[i++] = Call(
                $.curator,
                address(0xdead),
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );

            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam(uint32(0), to, 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );

            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, bytes32(0), 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );

            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, new bytes(50), "", ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", new bytes(50), ""),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", new bytes(50)),
                        ILayerZeroOFT.MessagingFee(1, 0),
                        $.subvault
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encodeCall(
                    ILayerZeroOFT.send,
                    (
                        ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", ""),
                        ILayerZeroOFT.MessagingFee(1, 1),
                        $.subvault
                    )
                ),
                false
            );
            tmp[i++] = Call(
                $.curator,
                $.sourceOFT,
                1 wei,
                abi.encode(
                    ILayerZeroOFT.send.selector,
                    ILayerZeroOFT.SendParam($.dstEid, to, 1, 1, "", "", ""),
                    ILayerZeroOFT.MessagingFee(1, 0),
                    $.subvault
                ),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }

        assembly {
            mstore(calls, iterator)
        }
    }
}
