// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../ABILibrary.sol";
import {ArraysLibrary} from "../ArraysLibrary.sol";
import {JsonLibrary} from "../JsonLibrary.sol";
import {ParameterLibrary} from "../ParameterLibrary.sol";
import {ProofLibrary} from "../ProofLibrary.sol";
import {ERC20Library} from "./ERC20Library.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/ICCIPRouterClient.sol";
import "../interfaces/Imports.sol";
import "../libraries/CCIPClient.sol";

import "./ERC20Library.sol";

library CCIPLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        address asset;
        address ccipRouter;
        uint64 targetChainSelector;
        address targetChainReceiver;
        string targetChainName;
    }

    function getCCIPProofs(BitmaskVerifier bitmaskVerifier, Info memory $)
        internal
        pure
        returns (IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](2);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.ccipRouter))
                })
            ),
            iterator
        );

        CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        tokenAmounts[0].token = $.asset;
        CCIPClient.EVMTokenAmount[] memory tokenAmountsMask = new CCIPClient.EVMTokenAmount[](1);
        tokenAmountsMask[0].token = address(type(uint160).max);
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            $.ccipRouter,
            0,
            abi.encodeCall(
                ICCIPRouterClient.ccipSend,
                (
                    $.targetChainSelector,
                    CCIPClient.EVM2AnyMessage({
                        receiver: abi.encode($.targetChainReceiver),
                        data: new bytes(0),
                        tokenAmounts: tokenAmounts,
                        feeToken: address(0),
                        extraArgs: CCIPClient._argsToBytes(
                            CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                        )
                    })
                )
            ),
            ProofLibrary.makeBitmask(
                true,
                true,
                false,
                true,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        type(uint64).max,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(address(type(uint160).max)),
                            data: new bytes(0),
                            tokenAmounts: tokenAmountsMask,
                            feeToken: address(type(uint160).max),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: type(uint256).max, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                )
            )
        );
    }

    function getCCIPDescriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](2);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.ccipRouter))
                })
            ),
            iterator
        );
        CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        tokenAmounts[0].token = $.asset;
        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.build("destinationChainSelector", Strings.toString($.targetChainSelector))
            .addJson(
            "message",
            JsonLibrary.toJson(
                CCIPClient.EVM2AnyMessage({
                    receiver: abi.encode($.targetChainReceiver),
                    data: new bytes(0),
                    tokenAmounts: tokenAmounts,
                    feeToken: address(0),
                    extraArgs: CCIPClient._argsToBytes(
                        CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                    )
                })
            )
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "CCIPRouterClient.ccipSend(ChainSelector(",
                    $.targetChainName,
                    "), [abi.encode(",
                    Strings.toHexString($.subvault),
                    "), 0x, [[",
                    IERC20Metadata($.asset).symbol(),
                    ", any]], 0x0000000000000000000000000000000000000000, 0x181dcf1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001])"
                )
            ),
            ABILibrary.getABI(ICCIPRouterClient.ccipSend.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString($.ccipRouter), "any"),
            innerParameters
        );
    }

    function getCCIPCalls(Info memory $) internal pure returns (Call[][] memory calls) {
        calls = new Call[][](2);

        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode($.asset)),
                    to: ArraysLibrary.makeAddressArray(abi.encode($.ccipRouter))
                })
            ),
            iterator
        );

        {
            CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
            address curator = $.curator;
            tokenAmounts[0].token = $.asset;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                true
            );
            tokenAmounts[0].amount = 1 ether;
            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                address(0xdead),
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        uint64(0xdead),
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(address(0xdead)),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(100),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: new CCIPClient.EVMTokenAmount[](2),
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0xdead),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0xdead, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: false})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encode(
                    ICCIPRouterClient.ccipSend.selector,
                    $.targetChainSelector,
                    CCIPClient.EVM2AnyMessage({
                        receiver: abi.encode($.targetChainReceiver),
                        data: new bytes(0),
                        tokenAmounts: tokenAmounts,
                        feeToken: address(0),
                        extraArgs: CCIPClient._argsToBytes(
                            CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                        )
                    })
                ),
                false
            );

            tokenAmounts[0].token = address(0xdead);
            tmp[i++] = Call(
                curator,
                $.ccipRouter,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.targetChainSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.targetChainReceiver),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls[iterator++] = tmp;
        }
    }
}
