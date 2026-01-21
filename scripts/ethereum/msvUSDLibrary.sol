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

import {CCTPLibrary} from "../common/protocols/CCTPLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";
import {ERC20Library} from "../common/protocols/ERC20Library.sol";
import {ERC4626Library} from "../common/protocols/ERC4626Library.sol";

import {KyberswapLibrary} from "../common/protocols/KyberswapLibrary.sol";
import {OFTLibrary} from "../common/protocols/OFTLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library msvUSDLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvaultEth;
        address subvaultArb;
        address swapModule;
        string subvaultEthName;
        string subvaultArbName;
        string targetChainName;
        address oftUSDT;
        address fUSDT; // fluid USDT fToken
        address fUSDC; // fluid USDC fToken
        address[] swapModuleAssets;
        address kyberRouter;
        address[] kyberSwapAssets;
    }

    function _getCCTPParams(Info memory $) internal pure returns (CCTPLibrary.Info memory) {
        return CCTPLibrary.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            subvaultTarget: $.subvaultArb,
            subvaultTargetName: $.subvaultArbName,
            targetChainName: $.targetChainName,
            tokenMessenger: Constants.CCTP_ETHEREUM_TOKEN_MESSENGER,
            destinationCaller: $.curator,
            destinationDomain: Constants.CCTP_ARBITRUM_DOMAIN,
            burnToken: Constants.USDC
        });
    }

    function _getOFTParams(Info memory $) internal pure returns (OFTLibrary.Info memory) {
        return OFTLibrary.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            targetSubvault: $.subvaultArb,
            approveRequired: true,
            sourceOFT: $.oftUSDT,
            dstEid: Constants.LAYER_ZERO_ARBITRUM_EID,
            subvaultName: $.subvaultEthName,
            targetSubvaultName: $.subvaultArbName,
            targetChainName: $.targetChainName
        });
    }

    function _getERC4626Params(Info memory $, address[] memory assets)
        internal
        pure
        returns (ERC4626Library.Info memory)
    {
        return ERC4626Library.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            assets: assets
        });
    }

    function _getAaveParams(Info memory $) internal pure returns (AaveLibrary.Info memory) {
        return AaveLibrary.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: $.swapModuleAssets,
            loans: new address[](0),
            categoryId: 0
        });
    }

    function _getSwapModuleParams(Info memory $) internal pure returns (SwapModuleLibrary.Info memory) {
        address[] memory curators = new address[](1);
        curators[0] = $.curator;

        return SwapModuleLibrary.Info({
            curators: curators,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            swapModule: $.swapModule,
            assets: $.swapModuleAssets
        });
    }

    function _getCurveParams(Info memory $) internal pure returns (CurveLibrary.Info memory) {
        return CurveLibrary.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            pool: Constants.CURVE_USDC_USDT_POOL,
            gauge: Constants.CURVE_USDC_USDT_GAUGE,
            rewardMinter: Constants.CURVE_USDC_USDT_REWARD_MINTER
        });
    }

    function _getKyberswapParams(Info memory $) internal pure returns (KyberswapLibrary.Info memory) {
        return KyberswapLibrary.Info({
            curator: $.curator,
            subvault: $.subvaultEth,
            subvaultName: $.subvaultEthName,
            kyberRouter: $.kyberRouter,
            assets: $.kyberSwapAssets
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

        iterator = leaves.insert(CCTPLibrary.getCCTPProofs(bitmaskVerifier, _getCCTPParams($)), iterator);
        iterator = leaves.insert(OFTLibrary.getOFTProofs(bitmaskVerifier, _getOFTParams($)), iterator);
        iterator = leaves.insert(
            ERC4626Library.getERC4626Proofs(
                bitmaskVerifier, _getERC4626Params($, ArraysLibrary.makeAddressArray(abi.encode($.fUSDT, $.fUSDC)))
            ),
            iterator
        );
        iterator = leaves.insert(AaveLibrary.getAaveProofs(bitmaskVerifier, _getAaveParams($)), iterator);
        iterator = leaves.insert(CurveLibrary.getCurveProofs(bitmaskVerifier, _getCurveParams($)), iterator);
        iterator =
            leaves.insert(SwapModuleLibrary.getSwapModuleProofs(bitmaskVerifier, _getSwapModuleParams($)), iterator);
        iterator = leaves.insert(KyberswapLibrary.getKyberswapProofs(bitmaskVerifier, _getKyberswapParams($)), iterator);

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(descriptions, CCTPLibrary.getCCTPDescriptions(_getCCTPParams($)), iterator);
        iterator = ArraysLibrary.insert(descriptions, OFTLibrary.getOFTDescriptions(_getOFTParams($)), iterator);
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC4626Library.getERC4626Descriptions(
                _getERC4626Params($, ArraysLibrary.makeAddressArray(abi.encode($.fUSDT)))
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC4626Library.getERC4626Descriptions(
                _getERC4626Params($, ArraysLibrary.makeAddressArray(abi.encode($.fUSDC)))
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(descriptions, AaveLibrary.getAaveDescriptions(_getAaveParams($)), iterator);
        iterator = ArraysLibrary.insert(descriptions, CurveLibrary.getCurveDescriptions(_getCurveParams($)), iterator);
        iterator = ArraysLibrary.insert(
            descriptions, SwapModuleLibrary.getSwapModuleDescriptions(_getSwapModuleParams($)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, KyberswapLibrary.getKyberswapDescriptions(_getKyberswapParams($)), iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0Calls(Info memory $, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](100);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(calls_, CCTPLibrary.getCCTPCalls(_getCCTPParams($)), iterator);
        iterator = ArraysLibrary.insert(calls_, OFTLibrary.getOFTCalls(_getOFTParams($)), iterator);
        iterator = ArraysLibrary.insert(
            calls_,
            ERC4626Library.getERC4626Calls(_getERC4626Params($, ArraysLibrary.makeAddressArray(abi.encode($.fUSDT)))),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls_,
            ERC4626Library.getERC4626Calls(_getERC4626Params($, ArraysLibrary.makeAddressArray(abi.encode($.fUSDC)))),
            iterator
        );
        iterator = ArraysLibrary.insert(calls_, AaveLibrary.getAaveCalls(_getAaveParams($)), iterator);
        iterator = ArraysLibrary.insert(calls_, CurveLibrary.getCurveCalls(_getCurveParams($)), iterator);
        iterator = ArraysLibrary.insert(calls_, SwapModuleLibrary.getSwapModuleCalls(_getSwapModuleParams($)), iterator);
        iterator = ArraysLibrary.insert(calls_, KyberswapLibrary.getKyberswapCalls(_getKyberswapParams($)), iterator);

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}
