// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../common/ABILibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {BitmaskVerifier, Call, IVerifier, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {CCIPLibrary} from "../common/protocols/CCIPLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";

import {FluidLibrary} from "../common/protocols/FluidLibrary.sol";
import {OFTLibrary} from "../common/protocols/OFTLibrary.sol";

library PlasmaStrETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    struct Info {
        address curator;
        address subvault;
        string subvaultName;
        address ethereumSubvault;
        address asset;
        address ccipRouter;
        uint64 ccipEthereumSelector;
        address swapModule;
    }

    function _getWSTETH_CCIP_Params(Info memory $) internal pure returns (CCIPLibrary.Info memory) {
        return CCIPLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            asset: Constants.WSTETH,
            ccipRouter: Constants.CCIP_PLASMA_ROUTER,
            targetChainSelector: Constants.CCIP_ETHEREUM_CHAIN_SELECTOR,
            targetChainReceiver: Constants.STRETH_ETHEREUM_SUBVAULT_0,
            targetChainName: "ethereum"
        });
    }

    function _getUSDT_OFT_Params(Info memory $) internal pure returns (OFTLibrary.Info memory) {
        return OFTLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            targetSubvault: Constants.STRETH_ETHEREUM_SUBVAULT_5,
            approveRequired: false,
            sourceOFT: Constants.PLASMA_USDT_OFT_ADAPTER,
            dstEid: Constants.LAYER_ZERO_ETHEREUM_EID,
            subvaultName: "subvault0",
            targetSubvaultName: "subvault5-ethereum",
            targetChainName: "ethereum"
        });
    }

    function _getWSTUSR_OFT_Params(Info memory $) internal pure returns (OFTLibrary.Info memory) {
        return OFTLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            targetSubvault: Constants.STRETH_ETHEREUM_SUBVAULT_5,
            approveRequired: false,
            sourceOFT: Constants.PLASMA_WSTUSR_OFT_ADAPTER,
            dstEid: Constants.LAYER_ZERO_ETHEREUM_EID,
            subvaultName: "subvault0",
            targetSubvaultName: "subvault5-ethereum",
            targetChainName: "ethereum"
        });
    }

    function _getFluid_WSTUSR_USDT0_Params(Info memory $) internal pure returns (FluidLibrary.Info memory) {
        return FluidLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: "subvault0",
            fluidVault: Constants.PLASMA_FLUID_WSTUSR_USDT_VAULT,
            nft: Constants.PLASMA_FLUID_WSTUSR_USDT_NFT_ID
        });
    }

    function _getSubvault0_SwapModule_Params(Info memory $) internal pure returns (SwapModuleLibrary.Info memory) {
        return SwapModuleLibrary.Info({
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            swapModule: $.swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WXPL, Constants.USDT0))
        });
    }

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            leaves, CCIPLibrary.getCCIPProofs(bitmaskVerifier, _getWSTETH_CCIP_Params($)), iterator
        );
        iterator =
            ArraysLibrary.insert(leaves, OFTLibrary.getOFTProofs(bitmaskVerifier, _getUSDT_OFT_Params($)), iterator);
        iterator =
            ArraysLibrary.insert(leaves, OFTLibrary.getOFTProofs(bitmaskVerifier, _getWSTUSR_OFT_Params($)), iterator);
        iterator = ArraysLibrary.insert(
            leaves, FluidLibrary.getFluidProofs(bitmaskVerifier, _getFluid_WSTUSR_USDT0_Params($)), iterator
        );
        iterator = ArraysLibrary.insert(
            leaves, SwapModuleLibrary.getSwapModuleProofs(bitmaskVerifier, _getSubvault0_SwapModule_Params($)), iterator
        );
        assembly {
            mstore(leaves, iterator)
        }

        (merkleRoot, leaves) = ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator =
            ArraysLibrary.insert(descriptions, CCIPLibrary.getCCIPDescriptions(_getWSTETH_CCIP_Params($)), iterator);
        iterator = ArraysLibrary.insert(descriptions, OFTLibrary.getOFTDescriptions(_getUSDT_OFT_Params($)), iterator);
        iterator = ArraysLibrary.insert(descriptions, OFTLibrary.getOFTDescriptions(_getWSTUSR_OFT_Params($)), iterator);
        iterator = ArraysLibrary.insert(
            descriptions, FluidLibrary.getFluidDescriptions(_getFluid_WSTUSR_USDT0_Params($)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault0_SwapModule_Params($)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.calls = new Call[][](leaves.length);
        calls.payloads = leaves;
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(calls.calls, CCIPLibrary.getCCIPCalls(_getWSTETH_CCIP_Params($)), iterator);
        iterator = ArraysLibrary.insert(calls.calls, OFTLibrary.getOFTCalls(_getUSDT_OFT_Params($)), iterator);
        iterator = ArraysLibrary.insert(calls.calls, OFTLibrary.getOFTCalls(_getWSTUSR_OFT_Params($)), iterator);
        iterator =
            ArraysLibrary.insert(calls.calls, FluidLibrary.getFluidCalls(_getFluid_WSTUSR_USDT0_Params($)), iterator);
        iterator = ArraysLibrary.insert(
            calls.calls, SwapModuleLibrary.getSwapModuleCalls(_getSubvault0_SwapModule_Params($)), iterator
        );
    }
}
