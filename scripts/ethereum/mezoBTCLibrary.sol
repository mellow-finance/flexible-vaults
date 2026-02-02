// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ABILibrary} from "../common/ABILibrary.sol";
import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {Constants} from "./Constants.sol";

import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";

import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";

import {IPoolUniswapV3, IPositionManagerV3} from "../common/interfaces/IPositionManagerV3.sol";
import {IAllowanceTransfer, IPositionManagerV4} from "../common/interfaces/IPositionManagerV4.sol";

import {StateLibrary} from "../common/libraries/StateLibrary.sol";
import {AngleDistributorLibrary} from "../common/protocols/AngleDistributorLibrary.sol";
import {MorphoLibrary} from "../common/protocols/MorphoLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {UniswapV3Library} from "../common/protocols/UniswapV3Library.sol";
import {UniswapV4Library} from "../common/protocols/UniswapV4Library.sol";
import {YieldBasisLibrary} from "../common/protocols/YieldBasisLibrary.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console2.sol";

library mezoBTCLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info0 {
        address curator;
        address subvault;
        address swapModule;
        string subvaultName;
        address[] swapModuleAssets;
        address positionManagerV3;
        address[] uniswapV3Pools;
        address positionManagerV4;
        uint256[] uniswapV4TokenIds;
    }

    struct Info1 {
        address curator;
        address subvault;
        string subvaultName;
        address[] yieldBasisTokens;
    }

    function _getUniswapV3Params(Info0 memory $) internal pure returns (UniswapV3Library.Info memory) {
        return UniswapV3Library.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            positionManager: $.positionManagerV3,
            pools: $.uniswapV3Pools
        });
    }

    function _getUniswapV4Params(Info0 memory $) internal pure returns (UniswapV4Library.Info memory) {
        return UniswapV4Library.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            positionManager: $.positionManagerV4,
            tokenIds: $.uniswapV4TokenIds
        });
    }

    function _getSwapModuleParams(Info0 memory $) internal pure returns (SwapModuleLibrary.Info memory) {
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

    function _getAngleDistributorParams(Info0 memory $) internal pure returns (AngleDistributorLibrary.Info memory) {
        return AngleDistributorLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            angleDistributor: Constants.ANGLE_PROTOCOL_DISTRIBUTOR
        });
    }

    function _getYieldBasisParams(Info1 memory $) internal pure returns (YieldBasisLibrary.Info memory) {
        return YieldBasisLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            zap: Constants.YIELD_BASIS_ZAP,
            ybTokens: $.yieldBasisTokens
        });
    }

    function getBTCSubvault0Data(Info0 memory $)
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

    function getBTCSubvault1Data(Info1 memory $)
        internal
        view
        returns (
            bytes32 merkleRoot,
            IVerifier.VerificationPayload[] memory leaves,
            string[] memory descriptions,
            SubvaultCalls memory calls
        )
    {
        (merkleRoot, leaves) = _getBTCSubvault1Proofs($);
        descriptions = _getBTCSubvault1Descriptions($);
        calls = _getBTCSubvault1Calls($, leaves);
    }

    /*--------------------------------------------------------------------------------------
                            Subvault 0 (Uniswap V3, V4, Swap Module, Angle Distributor)                            
    --------------------------------------------------------------------------------------*/

    function _getBTCSubvault0Proofs(Info0 memory $)
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
        // angle distributor proofs
        iterator = leaves.insert(
            AngleDistributorLibrary.getAngleDistributorProofs(bitmaskVerifier, _getAngleDistributorParams($)), iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function _getBTCSubvault0Descriptions(Info0 memory $) private view returns (string[] memory descriptions) {
        descriptions = new string[](100);
        uint256 iterator = 0;

        // uniswapV3 descriptions
        iterator = descriptions.insert(UniswapV3Library.getUniswapV3Descriptions(_getUniswapV3Params($)), iterator);
        // uniswapV4 descriptions
        iterator = descriptions.insert(UniswapV4Library.getUniswapV4Descriptions(_getUniswapV4Params($)), iterator);
        // swap module descriptions
        iterator = descriptions.insert(SwapModuleLibrary.getSwapModuleDescriptions(_getSwapModuleParams($)), iterator);
        // angle distributor descriptions
        iterator = descriptions.insert(
            AngleDistributorLibrary.getAngleDistributorDescriptions(_getAngleDistributorParams($)), iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function _getBTCSubvault0Calls(Info0 memory $, IVerifier.VerificationPayload[] memory leaves)
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
        // angle distributor calls
        iterator =
            calls_.insert(AngleDistributorLibrary.getAngleDistributorCalls(_getAngleDistributorParams($)), iterator);

        calls.calls = calls_;

        assembly {
            mstore(calls_, iterator)
        }
    }

    /*----------------------------------------------------------------------------
                            Subvault 1 (YieldBasis)                             
    ----------------------------------------------------------------------------*/
    function _getBTCSubvault1Proofs(Info1 memory $)
        private
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](100);
        uint256 iterator = 0;

        // yieldBasis proofs
        iterator =
            leaves.insert(YieldBasisLibrary.getYieldBasisProofs(bitmaskVerifier, _getYieldBasisParams($)), iterator);

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function _getBTCSubvault1Descriptions(Info1 memory $) private view returns (string[] memory descriptions) {
        descriptions = new string[](100);
        uint256 iterator = 0;

        // yieldBasis descriptions
        iterator = descriptions.insert(YieldBasisLibrary.getYieldBasisDescriptions(_getYieldBasisParams($)), iterator);

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function _getBTCSubvault1Calls(Info1 memory $, IVerifier.VerificationPayload[] memory leaves)
        private
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](100);
        uint256 iterator = 0;

        // yieldBasis calls
        iterator = calls_.insert(YieldBasisLibrary.getYieldBasisCalls(_getYieldBasisParams($)), iterator);

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }

    function getRanges(int24 tickSpot, int24 tickRange)
        internal
        pure
        returns (int24[] memory tickLower, int24[] memory tickUpper)
    {
        tickLower = new int24[](4);
        tickUpper = new int24[](4);
        //    [tickSpot - tickRange / 2, tickSpot - tickRange / 4, tickSpot - tickRange / 2, tickSpot];
        tickLower[0] = tickSpot - tickRange / 2;
        tickLower[1] = tickSpot - tickRange / 4;
        tickLower[2] = tickSpot - tickRange / 2;
        tickLower[3] = tickSpot;
        // [tickSpot + tickRange / 2, tickSpot + tickRange / 4, tickSpot, tickSpot + tickRange / 2];
        tickUpper[0] = tickSpot + tickRange / 2;
        tickUpper[1] = tickSpot + tickRange / 4;
        tickUpper[2] = tickSpot;
        tickUpper[3] = tickSpot + tickRange / 2;
        return (tickLower, tickUpper);
    }

    function mintTokenIdsV3(address[] memory pools, address subvault) internal {
        int24 tickRange = 100;
        for (uint256 i = 0; i < pools.length; i++) {
            (, int24 tick,,,,,) = IPoolUniswapV3(pools[i]).slot0();
            address token0 = IPoolUniswapV3(pools[i]).token0();
            address token1 = IPoolUniswapV3(pools[i]).token1();
            console2.log(
                "Minting Uniswap V3 positions at pool %s %s/%s",
                pools[i],
                IERC20Metadata(token0).symbol(),
                IERC20Metadata(token1).symbol()
            );
            IERC20(token0).approve(Constants.UNISWAP_V3_POSITION_MANAGER, type(uint256).max);
            IERC20(token1).approve(Constants.UNISWAP_V3_POSITION_MANAGER, type(uint256).max);
            (int24[] memory tickLower, int24[] memory tickUpper) = getRanges(tick, tickRange);
            for (uint256 j = 0; j < tickLower.length; j++) {
                IPositionManagerV3.MintParams memory mintParams = IPositionManagerV3.MintParams({
                    token0: address(token0),
                    token1: address(token1),
                    fee: IPoolUniswapV3(pools[i]).fee(),
                    tickLower: tickLower[j],
                    tickUpper: tickUpper[j],
                    amount0Desired: 10 ** (IERC20Metadata(token0).decimals() - 7), // 1e-7 BTC
                    amount1Desired: 10 ** (IERC20Metadata(token1).decimals() - 7), // 1e-7 BTC
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: subvault,
                    deadline: block.timestamp + 1 hours
                });
                (uint256 tokenId,,,) = IPositionManagerV3(Constants.UNISWAP_V3_POSITION_MANAGER).mint(mintParams);
                console2.log(
                    "Minted Uniswap V3 tokenId: %s [%s, %s]",
                    tokenId,
                    signedInt256ToString(int256(tickLower[j])),
                    signedInt256ToString(int256(tickUpper[j]))
                );
            }
        }
    }

    function mintTokenIdsV4(bytes25[] memory pools, address subvault) internal {
        address permit2 = IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).permit2();
        for (uint256 i = 0; i < pools.length; i++) {
            IPositionManagerV4.PoolKey memory poolKey =
                IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).poolKeys(pools[i]);
            console2.log(
                "Minting Uniswap V4 positions at pool %s/%s",
                IERC20Metadata(poolKey.currency0).symbol(),
                IERC20Metadata(poolKey.currency1).symbol()
            );

            IERC20(poolKey.currency0).approve(permit2, type(uint256).max);
            IERC20(poolKey.currency1).approve(permit2, type(uint256).max);
            IAllowanceTransfer(permit2).approve(
                poolKey.currency0,
                Constants.UNISWAP_V4_POSITION_MANAGER,
                type(uint160).max,
                uint48(block.timestamp + 1 hours)
            );
            IAllowanceTransfer(permit2).approve(
                poolKey.currency1,
                Constants.UNISWAP_V4_POSITION_MANAGER,
                type(uint160).max,
                uint48(block.timestamp + 1 hours)
            );
            bytes memory actions = abi.encodePacked(uint8(0x02), uint8(0x0d)); // mint, settle
            bytes[] memory params = new bytes[](2);
            params[1] = abi.encode(poolKey.currency0, poolKey.currency1); // settle params

            int24[] memory tickLower;
            int24[] memory tickUpper;
            {
                (, int24 tick,,) = StateLibrary.getSlot0(
                    IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).poolManager(), StateLibrary.toId(poolKey)
                );
                (tickLower, tickUpper) = getRanges(tick, 100);
            }

            for (uint256 j = 0; j < tickLower.length; j++) {
                uint256[] memory decimals = new uint256[](2);
                decimals[0] = IERC20Metadata(poolKey.currency0).decimals();
                decimals[1] = IERC20Metadata(poolKey.currency1).decimals();
                // poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData
                params[0] = abi.encode(
                    poolKey,
                    tickLower[j],
                    tickUpper[j],
                    10 ** ((decimals[0] + decimals[1]) / 2 - 7), // 1e-7 BTC liquidity
                    10 ** (decimals[0] - 7),
                    10 ** (decimals[1] - 7),
                    subvault,
                    ""
                );

                uint256 tokenId = IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).nextTokenId();
                IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
                    abi.encode(actions, params), block.timestamp + 1 hours
                );
                require(
                    IPositionManagerV4(Constants.UNISWAP_V4_POSITION_MANAGER).ownerOf(tokenId) == subvault, "Not owner"
                );
                console2.log(
                    "Minted Uniswap V4 tokenId: %s [%s, %s]",
                    tokenId,
                    signedInt256ToString(int256(tickLower[j])),
                    signedInt256ToString(int256(tickUpper[j]))
                );
            }
        }
    }

    function signedInt256ToString(int256 value) internal pure returns (string memory) {
        if (value >= 0) {
            return string(abi.encodePacked("+", Strings.toString(uint256(value))));
        } else {
            return string(abi.encodePacked("-", Strings.toString(uint256(-value))));
        }
    }
}
