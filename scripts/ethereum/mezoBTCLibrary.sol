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

import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {UniswapV4Library} from "../common/protocols/UniswapV4Library.sol";
import {Constants} from "./Constants.sol";

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
        address positionManager;
        address[] uniswapV4Assets;
    }

    function _getUniswapV4Params(Info memory $) internal pure returns (UniswapV4Library.Info memory) {
        return
            UniswapV4Library.Info({curator: $.curator, positionManager: $.positionManager, assets: $.uniswapV4Assets});
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

    function getBTCSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;

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

    function getBTCSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        descriptions = new string[](50);
        uint256 iterator = 0;
        // uniswapV4 descriptions
        iterator = descriptions.insert(UniswapV4Library.getUniswapV4Descriptions(_getUniswapV4Params($)), iterator);
        // swap module descriptions
        iterator = descriptions.insert(SwapModuleLibrary.getSwapModuleDescriptions(_getSwapModuleParams($)), iterator);
    }

    function getBTCSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](100);
        uint256 iterator = 0;

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
