// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/ABILibrary.sol";

import "../common/JsonLibrary.sol";
import "../common/ParameterLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";
import {BitmaskVerifier, Call, IVerifier, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ICCIPRouterClient} from "../common/interfaces/ICCIPRouterClient.sol";
import {CCIPClient} from "../common/libraries/CCIPClient.sol";

library PlasmaStrETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address ethereumSubvault;
        address asset;
        address ccipRouter;
        uint64 ccipEthereumSelector;
    }

    function getPlasmaStrETHProofs(Info memory info)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](2);

        {
            leaves[0] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                info.curator,
                info.asset,
                0,
                abi.encodeCall(IERC20.approve, (info.ccipRouter, 0)),
                ProofLibrary.makeBitmask(
                    true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
                )
            );
        }

        {
            CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
            tokenAmounts[0].token = info.asset;
            CCIPClient.EVMTokenAmount[] memory tokenAmountsMask = new CCIPClient.EVMTokenAmount[](1);
            tokenAmountsMask[0].token = address(type(uint160).max);
            leaves[1] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                info.curator,
                info.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        info.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(info.ethereumSubvault),
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
        (merkleRoot, leaves) = ProofLibrary.generateMerkleProofs(leaves);
    }

    function getPlasmaStrETHDescriptions(Info memory info) internal pure returns (string[] memory descriptions) {
        descriptions = new string[](2);

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2("to", Strings.toHexString(info.ccipRouter), "amount", "any");

        descriptions[0] = JsonLibrary.toJson(
            string(abi.encodePacked("WstETH.approve(ccipRouter, any)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString(info.curator), Strings.toHexString(info.asset), "0"),
            innerParameters
        );

        CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        tokenAmounts[0].token = info.asset;
        innerParameters = ParameterLibrary.build(
            "destinationChainSelector", Strings.toString(info.ccipEthereumSelector)
        ).addJson(
            "message",
            JsonLibrary.toJson(
                CCIPClient.EVM2AnyMessage({
                    receiver: abi.encode(info.ethereumSubvault),
                    data: new bytes(0),
                    tokenAmounts: tokenAmounts,
                    feeToken: address(0),
                    extraArgs: CCIPClient._argsToBytes(
                        CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                    )
                })
            )
        );

        descriptions[1] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "CCIPRouterClient.ccipSend(CCIP_ETHEREUM_CHAIN_SELECTOR, [abi.encode(ethereumSubvault0), 0x, [[WstETH, any]], 0x0000000000000000000000000000000000000000, 0x181dcf1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001])"
                )
            ),
            ABILibrary.getABI(ICCIPRouterClient.ccipSend.selector),
            ParameterLibrary.build(Strings.toHexString(info.curator), Strings.toHexString(info.ccipRouter), "any"),
            innerParameters
        );
    }

    function getPlasmaStrETHCalls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.calls = new Call[][](2);
        calls.payloads = leaves;
        uint256 index = 0;
        {
            Call[] memory tmp = new Call[](10);
            uint256 i = 0;
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.ccipRouter, 0)), true);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, ($.ccipRouter, 1 ether)), true);
            tmp[i++] = Call(address(0xdead), $.asset, 0, abi.encodeCall(IERC20.approve, ($.ccipRouter, 0)), false);
            tmp[i++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, ($.ccipRouter, 0)), false);
            tmp[i++] = Call($.curator, $.asset, 1 wei, abi.encodeCall(IERC20.approve, ($.ccipRouter, 0)), false);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 0)), false);
            tmp[i++] = Call($.curator, $.asset, 0, abi.encode(IERC20.approve.selector, $.ccipRouter, 0), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[index++] = tmp;
        }

        {
            CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
            tokenAmounts[0].token = $.asset;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0.1 ether,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        uint64(0xdead),
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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

            tokenAmounts[0].token = address(0xdead);
            tmp[i++] = Call(
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
                            data: new bytes(0),
                            tokenAmounts: tokenAmounts,
                            feeToken: address(0xdead),
                            extraArgs: CCIPClient._argsToBytes(
                                CCIPClient.EVMExtraArgsV2({gasLimit: 100, allowOutOfOrderExecution: true})
                            )
                        })
                    )
                ),
                false
            );

            tmp[i++] = Call(
                $.curator,
                $.ccipRouter,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        $.ccipEthereumSelector,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode($.ethereumSubvault),
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
                $.curator,
                $.ccipRouter,
                0,
                abi.encode(
                    ICCIPRouterClient.ccipSend.selector,
                    $.ccipEthereumSelector,
                    CCIPClient.EVM2AnyMessage({
                        receiver: abi.encode($.ethereumSubvault),
                        data: new bytes(0),
                        tokenAmounts: tokenAmounts,
                        feeToken: address(0xdead),
                        extraArgs: CCIPClient._argsToBytes(
                            CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                        )
                    })
                ),
                false
            );

            assembly {
                mstore(tmp, i)
            }
            calls.calls[index++] = tmp;
        }
    }
}
