// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAavePoolV3} from "../common/interfaces/IAavePoolV3.sol";
import {IL1GatewayRouter} from "../common/interfaces/IL1GatewayRouter.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";

import {CCIPLibrary} from "../common/protocols/CCIPLibrary.sol";
import {ERC20Library} from "../common/protocols/ERC20Library.sol";
import {OFTLibrary} from "../common/protocols/OFTLibrary.sol";
import {ResolvLibrary} from "../common/protocols/ResolvLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {ICCIPRouterClient} from "../common/interfaces/ICCIPRouterClient.sol";
import {CCIPClient} from "../common/libraries/CCIPClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library strETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function _getSubvault0WethParams(address curator) internal pure returns (WethLibrary.Info memory) {
        return WethLibrary.Info(curator, Constants.WETH);
    }

    function _getSubvault0SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault0",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
        });
    }

    function _getSubvault0CCIPPlasmaParams(address curator, address subvault)
        internal
        pure
        returns (CCIPLibrary.Info memory)
    {
        return CCIPLibrary.Info({
            curator: curator,
            subvault: subvault,
            asset: Constants.WSTETH,
            ccipRouter: Constants.CCIP_ETHEREUM_ROUTER,
            targetChainSelector: Constants.CCIP_PLASMA_CHAIN_SELECTOR,
            targetChainReceiver: Constants.STRETH_PLASMA_SUBVAULT_0,
            targetChainName: "plasma"
        });
    }

    function getSubvault0Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        leaves[iterator++] = WethLibrary.getWethDepositProof(bitmaskVerifier, _getSubvault0WethParams(curator));
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault0SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );

        iterator = ArraysLibrary.insert(
            leaves,
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH))
                })
            ),
            iterator
        );

        // arbitrum native bridge
        {
            bytes memory data =
                hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
            bytes memory encodedCall = abi.encodeCall(
                IL1GatewayRouter.outboundTransfer,
                (address(type(uint160).max), address(type(uint160).max), 0, 0, 0, data)
            );
            leaves[iterator++] = ProofLibrary.makeVerificationPayload(
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

        iterator = ArraysLibrary.insert(
            leaves,
            CCIPLibrary.getCCIPProofs(bitmaskVerifier, _getSubvault0CCIPPlasmaParams(curator, subvault)),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault0SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH))
                })
            ),
            iterator
        );

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2(
            "_token",
            Strings.toHexString(Constants.WSTETH),
            "_to",
            Strings.toHexString(Constants.STRETH_ARBITRUM_SUBVAULT_0)
        );
        innerParameters = innerParameters.add2("_amount", "any", "_maxGas", "any");
        innerParameters = innerParameters.add2("_gasPriceBid", "any", "_data", "any");
        descriptions[iterator++] = JsonLibrary.toJson(
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

        iterator = ArraysLibrary.insert(
            descriptions, CCIPLibrary.getCCIPDescriptions(_getSubvault0CCIPPlasmaParams(curator, subvault)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;

        calls.calls[iterator++] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault0SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls,
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.ARBITRUM_L1_TOKEN_GATEWAY_WSTETH))
                })
            ),
            iterator
        );

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

            calls.calls[iterator++] = tmp;
        }

        iterator = ArraysLibrary.insert(
            calls.calls, CCIPLibrary.getCCIPCalls(_getSubvault0CCIPPlasmaParams(curator, subvault)), iterator
        );
    }

    function _getSubvault1SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
        });
    }

    function _getSubvault1AavePrimeParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator,
            aaveInstance: Constants.AAVE_PRIME,
            aaveInstanceName: "Prime",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 1
        });
    }

    function _getSubvault1AaveCoreParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 1
        });
    }

    function getSubvault1Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault1SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault1AavePrimeParams(curator, subvault)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves, AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
        assembly {
            mstore(leaves, iterator)
        }
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault1SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault1AavePrimeParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault1SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault1AavePrimeParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
    }

    function _getSubvault2AaveParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault2",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            loans: ArraysLibrary.makeAddressArray(
                abi.encode(Constants.USDC, Constants.USDT, Constants.USDS, Constants.USDE)
            ),
            categoryId: 0
        });
    }

    function getSubvault2Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        return ProofLibrary.generateMerkleProofs(
            AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault2AaveParams(curator, subvault))
        );
    }

    function getSubvault2Descriptions(address curator, address subvault) internal view returns (string[] memory) {
        return AaveLibrary.getAaveDescriptions(_getSubvault2AaveParams(curator, subvault));
    }

    function getSubvault2SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = AaveLibrary.getAaveCalls(_getSubvault2AaveParams(curator, subvault));
    }

    function _getSubvault3AaveParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault3",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
            categoryId: 2
        });
    }

    function _getSubvault3SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault3",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(
                abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS, Constants.WETH)
            )
        });
    }

    function getSubvault3Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves, AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault3AaveParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault3SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault3Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault3AaveParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault3SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault3SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault3AaveParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault3SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
    }

    function _getSubvault4SparkParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault4",
            curator: curator,
            aaveInstance: Constants.SPARK,
            aaveInstanceName: "SparkLend",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 1
        });
    }

    function _getSubvault4SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault4",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
        });
    }

    function getSubvault4Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault4SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves, AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault4SparkParams(curator, subvault)), iterator
        );
        assembly {
            mstore(leaves, iterator)
        }
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault4Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault4SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault4SparkParams(curator, subvault)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault4SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault4SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault4SparkParams(curator, subvault)), iterator
        );
    }

    function _getSubvault5SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault5",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDE))
        });
    }

    function _getSubvault5ResolvParams(address curator, address subvault)
        internal
        pure
        returns (ResolvLibrary.Info memory)
    {
        return ResolvLibrary.Info({
            asset: Constants.USDT,
            usrRequestManager: Constants.USR_REQUEST_MANAGER,
            usr: Constants.USR,
            wstUSR: Constants.WSTUSR,
            subvault: subvault,
            subvaultName: "subvault5",
            curator: curator
        });
    }

    function _getSubvault5_USDT_OFT_Params(address curator, address subvault)
        internal
        pure
        returns (OFTLibrary.Info memory)
    {
        return OFTLibrary.Info({
            curator: curator,
            subvault: subvault,
            targetSubvault: Constants.STRETH_PLASMA_SUBVAULT_0,
            approveRequired: true,
            sourceOFT: Constants.ETHEREUM_USDT_OFT_ADAPTER,
            dstEid: Constants.LAYER_ZERO_PLASMA_EID,
            subvaultName: "subvault5",
            targetSubvaultName: "subvault0-plasma",
            targetChainName: "plasma"
        });
    }

    function _getSubvault5_WSTUSR_OFT_Params(address curator, address subvault)
        internal
        pure
        returns (OFTLibrary.Info memory)
    {
        return OFTLibrary.Info({
            curator: curator,
            subvault: subvault,
            targetSubvault: Constants.STRETH_PLASMA_SUBVAULT_0,
            approveRequired: true,
            sourceOFT: Constants.ETHEREUM_WSTUSR_OFT_ADAPTER,
            dstEid: Constants.LAYER_ZERO_PLASMA_EID,
            subvaultName: "subvault5",
            targetSubvaultName: "subvault0-plasma",
            targetChainName: "plasma"
        });
    }

    function getSubvault5Proofs(address curator, address subvault, address swapModule)
        internal
        view
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault5SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            ResolvLibrary.getResolvProofs(bitmaskVerifier, _getSubvault5ResolvParams(curator, subvault)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves, OFTLibrary.getOFTProofs(bitmaskVerifier, _getSubvault5_USDT_OFT_Params(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            OFTLibrary.getOFTProofs(bitmaskVerifier, _getSubvault5_WSTUSR_OFT_Params(curator, subvault)),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault5Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault5SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, ResolvLibrary.getResolvDescriptions(_getSubvault5ResolvParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, OFTLibrary.getOFTDescriptions(_getSubvault5_USDT_OFT_Params(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, OFTLibrary.getOFTDescriptions(_getSubvault5_WSTUSR_OFT_Params(curator, subvault)), iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault5SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault5SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, ResolvLibrary.getResolvCalls(_getSubvault5ResolvParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, OFTLibrary.getOFTCalls(_getSubvault5_USDT_OFT_Params(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, OFTLibrary.getOFTCalls(_getSubvault5_WSTUSR_OFT_Params(curator, subvault)), iterator
        );
    }

    function _getSubvault6SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault6",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.RSETH))
        });
    }

    function _getSubvault6AavePrimeParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault6",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.RSETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 3
        });
    }

    function getSubvault6Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault6SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault6AavePrimeParams(curator, subvault)),
            iterator
        );
        assembly {
            mstore(leaves, iterator)
        }
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault6Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault6SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault6AavePrimeParams(curator, subvault)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault6SubvaultCalls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault6SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault6AavePrimeParams(curator, subvault)), iterator
        );
    }
}
