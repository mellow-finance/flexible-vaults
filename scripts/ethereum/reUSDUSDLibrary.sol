// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";

import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {IAavePoolV3} from "../common/interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";

import {ITermMaxRouter} from "../common/interfaces/ITermMaxRouter.sol";
import {BracketVaultLibrary} from "../common/protocols/BracketVaultLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";

import {ERC20Library} from "../common/protocols/ERC20Library.sol";
import {ERC4626Library} from "../common/protocols/ERC4626Library.sol";

import {IInsuranceCapitalLayer, IRedemptionGateway} from "../common/interfaces/IReUSD.sol";
import {IStakedUSDeV2} from "../common/interfaces/IStakedUSDeV2.sol";
import {TermMaxLibrary} from "../common/protocols/TermMaxLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";
import {Constants} from "./Constants.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library reUSDUSDLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        string subvaultName;
        address curator;
        address subvault;
        address termmaxMarket;
        address swapModule;
    }

    /*
        0. IERC20(USDC).approve(reUSD, ...)
        1. IERC20(RedemptionGateway).approve(reUSD, ...)
        2. InsuranceCapitalLayer.deposit(USDC, ..., ...) -> reUSD
        3. RedemptionGateway.redeemInstant(..., ...) reUSD -> sUSDe
        4. Unstake sUSDe to sUSD
        4. ITermMax calls
        5. SwapModule sUSDe, USDC, USDU on Curve
    */
    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        /// @dev approves for USDC and reUSD
        iterator = leaves.insert(
            ERC20Library.getERC20Proofs(
                bitmaskVerifier,
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.REUSD)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.REUSD_ICL, Constants.REUSD_REDEMPTION_GATEWAY))
                })
            ),
            iterator
        );

        /// @dev deposit USDC into InsuranceCapitalLayer to mint reUSD
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            Constants.REUSD_ICL,
            0,
            abi.encodeCall(IInsuranceCapitalLayer.deposit, (Constants.USDC, 0, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IInsuranceCapitalLayer.deposit, (address(type(uint160).max), 0, 0))
            )
        );

        /// @dev redeem reUSD for sUSDe via RedemptionGateway
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            Constants.REUSD_REDEMPTION_GATEWAY,
            0,
            abi.encodeCall(IRedemptionGateway.redeemInstant, (0, 0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IRedemptionGateway.redeemInstant, (0, 0)))
        );

        /// @dev unstake sUSDe to sUSD
        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            $.curator,
            Constants.SUSDE,
            0,
            abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)))
        );

        /// @dev termmax reUSD/USUD
        iterator = leaves.insert(
            TermMaxLibrary.getTermMaxProofs(
                bitmaskVerifier,
                TermMaxLibrary.Info({
                    curator: $.curator,
                    subvault: $.subvault,
                    router: Constants.TERMMAX_ROUTER,
                    market: $.termmaxMarket
                })
            ),
            iterator
        );

        /// @dev swap on Curve at SwapModule
        iterator = leaves.insert(
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier,
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: SwapModuleLibrary.getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](50);
        uint256 iterator = 0;

        /// @dev approves for USDC and reUSD
        iterator = descriptions.insert(
            ERC20Library.getERC20Descriptions(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.REUSD)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.REUSD_ICL, Constants.REUSD_REDEMPTION_GATEWAY))
                })
            ),
            iterator
        );

        /// @dev deposit USDC into InsuranceCapitalLayer to mint reUSD
        descriptions[iterator++] = JsonLibrary.toJson(
            "IInsuranceCapitalLayer.deposit(USDC, anyInt, anyInt)",
            ABILibrary.getABI(IInsuranceCapitalLayer.deposit.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(Constants.REUSD_ICL), "0"),
            ParameterLibrary.build("token", Strings.toHexString(Constants.USDC)).addAny("amount").addAny("minShares")
        );

        /// @dev redeem reUSD for sUSDe via RedemptionGateway
        descriptions[iterator++] = JsonLibrary.toJson(
            "IRedemptionGateway.redeemInstant(anyInt, anyInt)",
            ABILibrary.getABI(IRedemptionGateway.redeemInstant.selector),
            ParameterLibrary.build(
                Strings.toHexString($.curator), Strings.toHexString(Constants.REUSD_REDEMPTION_GATEWAY), "0"
            ),
            ParameterLibrary.build("shares", "any").addAny("minPayout")
        );

        /// @dev unstake sUSDe to sUSD
        descriptions[iterator++] = JsonLibrary.toJson(
            "IStakedUSDeV2.cooldownShares(anyInt)",
            ABILibrary.getABI(IStakedUSDeV2.cooldownShares.selector),
            ParameterLibrary.build(Strings.toHexString($.curator), Strings.toHexString(Constants.SUSDE), "0"),
            ParameterLibrary.build("shares", "any")
        );

        /// @dev termmax reUSD/USUD
        iterator = descriptions.insert(
            TermMaxLibrary.getTermMaxDescriptions(
                TermMaxLibrary.Info({
                    curator: $.curator,
                    subvault: $.subvault,
                    router: Constants.TERMMAX_ROUTER,
                    market: $.termmaxMarket
                })
            ),
            iterator
        );

        /// @dev swap on Curve at SwapModule
        iterator = descriptions.insert(
            SwapModuleLibrary.getSwapModuleDescriptions(
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: SwapModuleLibrary.getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
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
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](50);
        uint256 iterator;

        /// @dev approves for USDC and reUSD
        iterator = calls_.insert(
            ERC20Library.getERC20Calls(
                ERC20Library.Info({
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.REUSD)),
                    to: ArraysLibrary.makeAddressArray(abi.encode(Constants.REUSD_ICL, Constants.REUSD_REDEMPTION_GATEWAY))
                })
            ),
            iterator
        );

        /// @dev deposit USDC into InsuranceCapitalLayer to mint reUSD
        {
            uint256 index = 0;
            Call[] memory tmp = new Call[](16);
            tmp[index++] = Call(
                $.curator,
                Constants.REUSD_ICL,
                0,
                abi.encodeCall(IInsuranceCapitalLayer.deposit, (Constants.USDC, 0, 0)),
                true
            );
            assembly {
                mstore(tmp, index)
            }
            calls_[iterator++] = tmp;
        }

        /// @dev redeem reUSD for sUSDe via RedemptionGateway
        {
            uint256 index = 0;
            Call[] memory tmp = new Call[](16);
            tmp[index++] = Call(
                $.curator,
                Constants.REUSD_REDEMPTION_GATEWAY,
                0,
                abi.encodeCall(IRedemptionGateway.redeemInstant, (0, 0)),
                true
            );
            tmp[index++] = Call(
                $.curator,
                Constants.REUSD_REDEMPTION_GATEWAY,
                0,
                abi.encodeCall(IRedemptionGateway.redeemInstant, (1 ether, 1 ether)),
                true
            );
            tmp[index++] = Call(
                $.curator,
                Constants.REUSD_REDEMPTION_GATEWAY,
                1 wei,
                abi.encodeCall(IRedemptionGateway.redeemInstant, (1 ether, 1 ether)),
                false
            );
            tmp[index++] = Call(
                address(0xdead),
                Constants.REUSD_REDEMPTION_GATEWAY,
                0,
                abi.encodeCall(IRedemptionGateway.redeemInstant, (1 ether, 1 ether)),
                false
            );
            tmp[index++] = Call(
                $.curator,
                address(0xdead),
                0,
                abi.encodeCall(IRedemptionGateway.redeemInstant, (1 ether, 1 ether)),
                false
            );
            assembly {
                mstore(tmp, index)
            }
            calls_[iterator++] = tmp;
        }

        /// @dev unstake sUSDe to sUSD
        {
            uint256 index = 0;
            Call[] memory tmp = new Call[](16);
            tmp[index++] = Call($.curator, Constants.SUSDE, 0, abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)), true);
            tmp[index++] =
                Call($.curator, Constants.SUSDE, 0, abi.encodeCall(IStakedUSDeV2.cooldownShares, (1 ether)), true);
            tmp[index++] =
                Call($.curator, Constants.SUSDE, 1 wei, abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)), false);
            tmp[index++] =
                Call(address(0xdead), Constants.SUSDE, 0, abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)), false);
            tmp[index++] = Call($.curator, address(0xdead), 0, abi.encodeCall(IStakedUSDeV2.cooldownShares, (0)), false);
            tmp[index++] =
                Call($.curator, Constants.SUSDE, 0, abi.encode(IStakedUSDeV2.cooldownShares.selector, 0), false);

            assembly {
                mstore(tmp, index)
            }
            calls_[iterator++] = tmp;
        }

        /// @dev termmax reUSD/USUD
        iterator = calls_.insert(
            TermMaxLibrary.getTermMaxCalls(
                TermMaxLibrary.Info({
                    curator: $.curator,
                    subvault: $.subvault,
                    router: Constants.TERMMAX_ROUTER,
                    market: $.termmaxMarket
                })
            ),
            iterator
        );

        /// @dev swap on Curve at SwapModule
        iterator = calls_.insert(
            SwapModuleLibrary.getSwapModuleCalls(
                SwapModuleLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    swapModule: $.swapModule,
                    curators: ArraysLibrary.makeAddressArray(abi.encode($.curator)),
                    assets: SwapModuleLibrary.getSwapModuleAssets(payable($.swapModule))
                })
            ),
            iterator
        );

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}
