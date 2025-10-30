// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAavePoolV3} from "../common/interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";
import {IL1GatewayRouter} from "../common/interfaces/IL1GatewayRouter.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {ICCIPRouterClient} from "../common/interfaces/ICCIPRouterClient.sol";
import {CCIPClient} from "../common/libraries/CCIPClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library strETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function getSubvault0Proofs(address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{value: <any>}();
            2-4. cowswap (assets=[weth])
            5. wsteth.approve(ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, any)
            6. ARBITRUM_L1_GATEWAY_ROUTER.outboundTransfer{value: any}(params...)
            7. wsteth.approve(ccipRouter, any)
            8. ccipRouter.ccipSend{value: any}(params...)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](8);
        leaves[0] = WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            1
        );

        leaves[4] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );

        {
            bytes memory data =
                hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
            bytes memory encodedCall = abi.encodeCall(
                IL1GatewayRouter.outboundTransfer,
                (address(type(uint160).max), address(type(uint160).max), 0, 0, 0, data)
            );
            leaves[5] = ProofLibrary.makeVerificationPayload(
                bitmaskVerifier,
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                0,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 0, 0, 0, data)
                ),
                ProofLibrary.makeBitmask(true, true, false, true, encodedCall)
            );
        }
        leaves[6] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );

        CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        tokenAmounts[0].token = Constants.WSTETH;
        CCIPClient.EVMTokenAmount[] memory tokenAmountsMask = new CCIPClient.EVMTokenAmount[](1);
        tokenAmountsMask[0].token = address(type(uint160).max);
        leaves[7] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.CCIP_ETHEREUM_ROUTER,
            0,
            abi.encodeCall(
                ICCIPRouterClient.ccipSend,
                (
                    Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                    CCIPClient.EVM2AnyMessage({
                        receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator) internal view returns (string[] memory descriptions) {
        descriptions = new string[](8);
        descriptions[0] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            1
        );

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2(
            "to", Strings.toHexString(Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH), "amount", "any"
        );
        descriptions[4] = JsonLibrary.toJson(
            string(abi.encodePacked("WstETH.approve(L1TokenGatewayWstETH, any)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString(curator), Strings.toHexString(Constants.WSTETH), "0"),
            innerParameters
        );

        innerParameters = ParameterLibrary.add2(
            "token_",
            Strings.toHexString(Constants.WSTETH),
            "to_",
            Strings.toHexString(Constants.STRETH_ARBITRUM_SUBVAULT_0)
        );
        innerParameters = innerParameters.add2("amount_", "any", "maxGas_", "any");
        innerParameters = innerParameters.add2("gasPriceBid_", "any", "data_", "any");
        descriptions[5] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "L1GatewayRouter.outboundTransfer{value: any}(WstETH, strETH_Subvault0_arbitrum, any, any, any, any)"
                )
            ),
            ABILibrary.getABI(IL1GatewayRouter.outboundTransfer.selector),
            ParameterLibrary.build(
                Strings.toHexString(curator), Strings.toHexString(Constants.ARBITRUM_L1_GATEWAY_ROUTER), "0"
            ),
            innerParameters
        );

        innerParameters =
            ParameterLibrary.add2("to", Strings.toHexString(Constants.CCIP_ETHEREUM_ROUTER), "amount", "any");
        descriptions[6] = JsonLibrary.toJson(
            string(abi.encodePacked("WstETH.approve(CCIPRouterClient, any)")),
            ABILibrary.getABI(IERC20.approve.selector),
            ParameterLibrary.build(Strings.toHexString(curator), Strings.toHexString(Constants.WSTETH), "0"),
            innerParameters
        );

        CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        tokenAmounts[0].token = Constants.WSTETH;
        innerParameters = ParameterLibrary.build(
            "destinationChainSelector", Strings.toString(Constants.CCIP_PLASMA_CHAIN_SELECTOR)
        ).addJson(
            "message",
            JsonLibrary.toJson(
                CCIPClient.EVM2AnyMessage({
                    receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
                    data: new bytes(0),
                    tokenAmounts: tokenAmounts,
                    feeToken: address(0),
                    extraArgs: CCIPClient._argsToBytes(
                        CCIPClient.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true})
                    )
                })
            )
        );
        descriptions[7] = JsonLibrary.toJson(
            string(
                abi.encodePacked(
                    "CCIPRouterClient.ccipSend(CCIP_PLASMA_CHAIN_SELECTOR, [abi.encode(arbitrumSubvault0), 0x, [[WstETH, any]], 0x0000000000000000000000000000000000000000, 0x181dcf1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001])"
                )
            ),
            ABILibrary.getABI(ICCIPRouterClient.ccipSend.selector),
            ParameterLibrary.build(
                Strings.toHexString(curator), Strings.toHexString(Constants.CCIP_ETHEREUM_ROUTER), "any"
            ),
            innerParameters
        );
    }

    function getSubvault0SubvaultCalls(address curator, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        calls.calls[0] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            1
        );

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                0,
                abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                0,
                abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 1 ether)),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                Constants.WSTETH,
                0,
                abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0)),
                false
            );
            tmp[i++] = Call(
                curator,
                address(0xdead),
                0,
                abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                1 wei,
                abi.encodeCall(IERC20.approve, (Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0)),
                false
            );
            tmp[i++] = Call(curator, Constants.WSTETH, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 0)), false);
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                0,
                abi.encode(IERC20.approve.selector, Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH, 0),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls.calls[4] = tmp;
        }

        {
            bytes memory data =
                hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";

            Call[] memory tmp = new Call[](10);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                0,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 0, 0, 0, data)
                ),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 1, 1, 1, data)
                ),
                true
            );

            tmp[i++] = Call(
                address(0xdead),
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 1, 1, 1, data)
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                address(0xdead),
                1 wei,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 1, 1, 1, data)
                ),
                false
            );

            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (address(0xdead), Constants.STRETH_ARBITRUM_SUBVAULT_0, 1, 1, 1, data)
                ),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encodeCall(IL1GatewayRouter.outboundTransfer, (Constants.WSTETH, address(0xdead), 1, 1, 1, data)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encodeCall(
                    IL1GatewayRouter.outboundTransfer,
                    (Constants.WSTETH, Constants.STRETH_ARBITRUM_SUBVAULT_0, 1, 1, 1, new bytes(100))
                ),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.ARBITRUM_L1_GATEWAY_ROUTER,
                1 wei,
                abi.encode(
                    IL1GatewayRouter.outboundTransfer.selector,
                    Constants.WSTETH,
                    Constants.STRETH_ARBITRUM_SUBVAULT_0,
                    1,
                    1,
                    1,
                    data
                ),
                false
            );

            assembly {
                mstore(tmp, i)
            }

            calls.calls[5] = tmp;
        }

        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator, Constants.WSTETH, 0, abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 0)), true
            );
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                0,
                abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 1 ether)),
                true
            );
            tmp[i++] = Call(
                address(0xdead),
                Constants.WSTETH,
                0,
                abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 0)),
                false
            );
            tmp[i++] = Call(
                curator, address(0xdead), 0, abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 0)), false
            );
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                1 wei,
                abi.encodeCall(IERC20.approve, (Constants.CCIP_ETHEREUM_ROUTER, 0)),
                false
            );
            tmp[i++] = Call(curator, Constants.WSTETH, 0, abi.encodeCall(IERC20.approve, (address(0xdead), 0)), false);
            tmp[i++] = Call(
                curator,
                Constants.WSTETH,
                0,
                abi.encode(IERC20.approve.selector, Constants.CCIP_ETHEREUM_ROUTER, 0),
                false
            );
            assembly {
                mstore(tmp, i)
            }
            calls.calls[6] = tmp;
        }

        {
            CCIPClient.EVMTokenAmount[] memory tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
            tokenAmounts[0].token = Constants.WSTETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.CCIP_ETHEREUM_ROUTER,
                0,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        uint64(0xdead),
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encode(
                    ICCIPRouterClient.ccipSend.selector,
                    Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                    CCIPClient.EVM2AnyMessage({
                        receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
                Constants.CCIP_ETHEREUM_ROUTER,
                1 wei,
                abi.encodeCall(
                    ICCIPRouterClient.ccipSend,
                    (
                        Constants.CCIP_PLASMA_CHAIN_SELECTOR,
                        CCIPClient.EVM2AnyMessage({
                            receiver: abi.encode(Constants.STRETH_PLASMA_SUBVAULT_0),
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
            calls.calls[7] = tmp;
        }
    }

    function getSubvault1Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-4. cowswap (assets=[weth, wsteth])
            5-11. aave (collaterals=[wsteth], loans=[weth], categoryId=1)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](11);
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            0
        );
        ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](11);
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            0
        );
        ArraysLibrary.insert(
            descriptions,
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
    }

    function getSubvault1SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        /*
            1. weth.approve(cowswap, anyInt)
            2. wsteth.approve(cowswap, anyInt)
            3. cowswap.setPreSignature(anyBytes(56), anyBool)
            4. cowswap.invalidateOrder(anyBytes(56))

            5. weth.approve(AaveV3Prime, anyInt)
            6. wsteth.approve(AaveV3Prime, anyInt)

            7. AaveV3Prime.setEMode(category=1)
            8. AaveV3Prime.borrow(weth, anyInt, 2, anyInt, subvault1)
            9. AaveV3Prime.repay(weth, anyInt, 2, subvault1)
            10. AaveV3Prime.supply(wsteth, anyInt, subvault1, anyInt)
            11. AaveV3Prime.withdraw(wsteth, anyInt, subvault1)
        */
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            4
        );
        ArraysLibrary.insert(
            calls.calls,
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
    }

    function getSubvault2Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-7. aave (collaterals=[wsteth], loans=[usdc, usdt, usds], categoryId=0)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        return ProofLibrary.generateMerkleProofs(
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault2",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 0
                })
            )
        );
    }

    function getSubvault2Descriptions(address curator, address subvault) internal view returns (string[] memory) {
        return AaveLibrary.getAaveDescriptions(
            AaveLibrary.Info({
                subvault: subvault,
                subvaultName: "subvault2",
                curator: curator,
                aaveInstance: Constants.AAVE_CORE,
                aaveInstanceName: "Core",
                collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                categoryId: 0
            })
        );
    }

    function getSubvault2SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = AaveLibrary.getAaveCalls(
            AaveLibrary.Info({
                subvault: subvault,
                subvaultName: "subvault2",
                curator: curator,
                aaveInstance: Constants.AAVE_CORE,
                aaveInstanceName: "Core",
                collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                categoryId: 0
            })
        );
    }

    function getSubvault3Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;

        leaves = new IVerifier.VerificationPayload[](23);
        ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault3Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        descriptions = new string[](23);
        ArraysLibrary.insert(
            descriptions,
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );
    }

    function getSubvault3SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        calls.payloads = leaves;
        calls.calls = new Call[][](23);
        ArraysLibrary.insert(
            calls.calls,
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );
    }
}
