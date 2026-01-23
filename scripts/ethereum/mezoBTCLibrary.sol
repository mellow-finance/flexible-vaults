// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../common/ABILibrary.sol";
import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";

import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {UniswapV3Library} from "../common/protocols/UniswapV3Library.sol";
import {UniswapV4Library} from "../common/protocols/UniswapV4Library.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library mezoBTCLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        address swapModule;
        string subvaultName;
        address[] swapModuleAssets;
        address positionManagerV3;
        address[] uniswapV3Pools;
        uint256[][] uniswapV3TokenIds;
        address positionManagerV4;
        address[] uniswapV4Assets;
    }

    function _getUniswapV3Params(Info memory $) internal pure returns (UniswapV3Library.Info memory) {
        return UniswapV3Library.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            positionManager: $.positionManagerV3,
            pools: $.uniswapV3Pools,
            tokenIds: $.uniswapV3TokenIds
        });
    }

    function _getUniswapV4Params(Info memory $) internal pure returns (UniswapV4Library.Info memory) {
        return
            UniswapV4Library.Info({curator: $.curator, positionManager: $.positionManagerV4, assets: $.uniswapV4Assets});
    }

    function _getSwapModuleParams(Info memory $) internal pure returns (SwapModuleLibrary.Info memory) {
        address[] memory curators = new address[](1);
        curators[0] = $.curator;

        return SwapModuleLibrary.Info({
            curators: curators,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            swapModule: $.swapModule,
            assets: $.swapModuleAssets
        });
    }

    function getBTCSubvault0Data(Info memory $)
        internal
        view
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls
        )
    {
        (merkleRoot, leaves) = _getBTCSubvault0Proofs($);
        descriptions = _getBTCSubvault0Descriptions($);
        calls = _getBTCSubvault0Calls($, leaves);
    }

    function _getBTCSubvault0Proofs(Info memory $)
        private
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](100);
        uint256 iterator = 0;

        // uniswapV3 proofs
        iterator = leaves.insert(UniswapV3Library.getUniswapV3Proofs(bitmaskVerifier, _getUniswapV3Params($)), iterator);
        // uniswapV4 proofs
        iterator = leaves.insert(UniswapV4Library.getUniswapV4Proofs(bitmaskVerifier, _getUniswapV4Params($)), iterator);
        // swap module proofs
        iterator =
            leaves.insert(SwapModuleLibrary.getSwapModuleProofs(bitmaskVerifier, _getSwapModuleParams($)), iterator);

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function _getBTCSubvault0Descriptions(Info memory $) private view returns (string[] memory descriptions) {
        descriptions = new string[](100);
        uint256 iterator = 0;
        // uniswapV3 descriptions
        iterator = descriptions.insert(UniswapV3Library.getUniswapV3Descriptions(_getUniswapV3Params($)), iterator);
        // uniswapV4 descriptions
        iterator = descriptions.insert(UniswapV4Library.getUniswapV4Descriptions(_getUniswapV4Params($)), iterator);
        // swap module descriptions
        iterator = descriptions.insert(SwapModuleLibrary.getSwapModuleDescriptions(_getSwapModuleParams($)), iterator);
    }

    function _getBTCSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        private
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](100);
        uint256 iterator = 0;

        // uniswapV3 calls
        iterator = calls_.insert(UniswapV3Library.getUniswapV3Calls(_getUniswapV3Params($)), iterator);
        // uniswapV4 calls
        iterator = calls_.insert(UniswapV4Library.getUniswapV4Calls(_getUniswapV4Params($)), iterator);
        // swap module calls
        iterator = calls_.insert(SwapModuleLibrary.getSwapModuleCalls(_getSwapModuleParams($)), iterator);

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}
