// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
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

import {DigiFTILibrary} from "../common/protocols/DigiFTILibrary.sol";
import {ERC20Library} from "../common/protocols/ERC20Library.sol";
import {ERC4626Library} from "../common/protocols/ERC4626Library.sol";

import {MorphoLibrary} from "../common/protocols/MorphoLibrary.sol";
import {MorphoStrategyWrapperLibrary} from "../common/protocols/MorphoStrategyWrapperLibrary.sol";

import {IMorphoStrategyWrapper} from "../common/interfaces/IMorphoStrategyWrapper.sol";
import {TermMaxLibrary} from "../common/protocols/TermMaxLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";
import {Constants} from "./Constants.sol";

library umUSDLibrary {
    struct Info {
        string subvaultName;
        address curator;
        address subvault;
        address termmaxMarket;
    }
    /**
     * subvault 0:
     *         - DigiFTI: uMINT <-> USDC
     *         - TermMax: borrow/repay USDU using uMINT as collateral
     *         - Curve swap: USDU <> USDC
     *     subvault 1:
     *         - Morpho: supply/withdraw USDC
     *         - MorphoStrategyWrapper: borrow/repay USDC using USDU as collateral
     *         - rewardVault 4626 interaction
     *         - Curve mint/burn liquidity USDU / USDC
     */

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
             0. IERC20(USDC).approve(SUB_RED_MANAGEMENT, ...) to buy uMINT for USDC
             1. IERC20(uMINT).approve(SUB_RED_MANAGEMENT, ...) to sell uMINT for USDC
             2. IERC20(uMINT).approve(TERMMAX_ROUTER, ...) to supply uMINT as collateral
             3. IERC20(USDU).approve(TERMMAX_ROUTER, ...) to repay USDU
             4. IERC20(USDU).approve(CURVE_POOL, ...) to swap USDU <> USDC
             5. IERC20(USDC).approve(CURVE_POOL, ...) to swap USDC <> USDU
             6. SUB_RED_MANAGEMENT.subscribe(UMINT, USDC, ...)
             7. SUB_RED_MANAGEMENT.redeem(UMINT, USDC, ...)
             8. TERMMAX_ROUTER.borrowTokenFromCollateral(subvault0, MARKET, ...) (uMINT->USDU)
             9. TERMMAX_ROUTER.repayGt(MARKET, ...) (USDU->uMINT)
            10. Swap USDU <> USDC on Curve
        */

        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator;

        /// @dev approves and borrow/repay USDU using uMINT as collateral
        iterator = ArraysLibrary.insert(
            leaves,
            DigiFTILibrary.getDigiFTProofs(
                bitmaskVerifier,
                DigiFTILibrary.Info({
                    curator: $.curator,
                    subRedManagement: Constants.SUB_RED_MANAGEMENT,
                    stToken: Constants.UMINT,
                    currencyToken: Constants.USDC
                })
            ),
            iterator
        );

        /// @dev approves and subscribe/redeem uMINT using USDC as collateral
        iterator = ArraysLibrary.insert(
            leaves,
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

        /// @dev swap USDU <> USDC on Curve
        iterator = ArraysLibrary.insert(
            leaves,
            CurveLibrary.getCurveExchangeProofs(
                bitmaskVerifier,
                CurveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
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

        /// @dev approves and borrow/repay USDU using uMINT as collateral
        iterator = ArraysLibrary.insert(
            descriptions,
            DigiFTILibrary.getDigiFTDescriptions(
                DigiFTILibrary.Info({
                    curator: $.curator,
                    subRedManagement: Constants.SUB_RED_MANAGEMENT,
                    stToken: Constants.UMINT,
                    currencyToken: Constants.USDC
                })
            ),
            iterator
        );
        /// @dev approves and subscribe/redeem uMINT using USDC as collateral
        iterator = ArraysLibrary.insert(
            descriptions,
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
        /// @dev swap USDU <> USDC on Curve
        iterator = ArraysLibrary.insert(
            descriptions,
            CurveLibrary.getCurveExchangeDescriptions(
                CurveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
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

        /// @dev approves and borrow/repay USDU using uMINT as collateral
        iterator = ArraysLibrary.insert(
            calls_,
            DigiFTILibrary.getDigiFTCalls(
                DigiFTILibrary.Info({
                    curator: $.curator,
                    subRedManagement: Constants.SUB_RED_MANAGEMENT,
                    stToken: Constants.UMINT,
                    currencyToken: Constants.USDC
                })
            ),
            iterator
        );

        /// @dev approves and subscribe/redeem uMINT using USDC as collateral
        iterator = ArraysLibrary.insert(
            calls_,
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

        /// @dev swap USDU <> USDC on Curve
        iterator = ArraysLibrary.insert(
            calls_,
            CurveLibrary.getCurveExchangeCalls(
                CurveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
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

library mAlphaMorphoLibrary {
    struct Info {
        string subvaultName;
        address curator;
        address subvault;
        address morphoStrategyWrapper;
    }

    function getInfos(Info memory $)
        internal
        view
        returns (
            MorphoLibrary.Info memory morphoLibraryInfo,
            MorphoStrategyWrapperLibrary.Info memory morphoStrategyWrapperLibraryInfo,
            CurveLibrary.Info memory curveLibraryInfo
        )
    {
        morphoLibraryInfo = MorphoLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            marketId: IMorphoStrategyWrapper($.morphoStrategyWrapper).lendingMarketId(),
            morpho: Constants.MORPHO_ETHEREUM
        });
        morphoStrategyWrapperLibraryInfo = MorphoStrategyWrapperLibrary.Info({
            curator: $.curator,
            subvault: $.subvault,
            morphoStrategyWrapper: $.morphoStrategyWrapper,
            morpho: Constants.MORPHO_ETHEREUM,
            subvaultName: $.subvaultName
        });
        curveLibraryInfo = CurveLibrary.Info({
            subvault: $.subvault,
            subvaultName: $.subvaultName,
            curator: $.curator,
            pool: Constants.CURVE_USDC_USDU_POOL,
            gauge: Constants.CURVE_USDC_USDU_GAUGE
        });
    }

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](100);
        (
            MorphoLibrary.Info memory morphoLibraryInfo,
            MorphoStrategyWrapperLibrary.Info memory morphoStrategyWrapperLibraryInfo,
            CurveLibrary.Info memory curveLibraryInfo
        ) = getInfos($);

        uint256 iterator;

        iterator =
            ArraysLibrary.insert(leaves, MorphoLibrary.getMorphoProofs(bitmaskVerifier, morphoLibraryInfo), iterator);
        iterator = ArraysLibrary.insert(
            leaves,
            MorphoStrategyWrapperLibrary.getMorphoStrategyProofs(bitmaskVerifier, morphoStrategyWrapperLibraryInfo),
            iterator
        );
        iterator =
            ArraysLibrary.insert(leaves, CurveLibrary.getCurveProofs(bitmaskVerifier, curveLibraryInfo), iterator);

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(Info memory $) internal view returns (string[] memory descriptions) {
        descriptions = new string[](100);
        (
            MorphoLibrary.Info memory morphoLibraryInfo,
            MorphoStrategyWrapperLibrary.Info memory morphoStrategyWrapperLibraryInfo,
            CurveLibrary.Info memory curveLibraryInfo
        ) = getInfos($);

        uint256 iterator;
        iterator = ArraysLibrary.insert(descriptions, MorphoLibrary.getMorphoDescriptions(morphoLibraryInfo), iterator);
        iterator = ArraysLibrary.insert(
            descriptions,
            MorphoStrategyWrapperLibrary.getMorphoStrategyDescriptions(morphoStrategyWrapperLibraryInfo),
            iterator
        );
        iterator = ArraysLibrary.insert(descriptions, CurveLibrary.getCurveDescriptions(curveLibraryInfo), iterator);

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
        Call[][] memory calls_ = new Call[][](100);
        uint256 iterator;
        (
            MorphoLibrary.Info memory morphoLibraryInfo,
            MorphoStrategyWrapperLibrary.Info memory morphoStrategyWrapperLibraryInfo,
            CurveLibrary.Info memory curveLibraryInfo
        ) = getInfos($);

        iterator = ArraysLibrary.insert(calls_, MorphoLibrary.getMorphoCalls(morphoLibraryInfo), iterator);
        iterator = ArraysLibrary.insert(
            calls_, MorphoStrategyWrapperLibrary.getMorphoStrategyCalls(morphoStrategyWrapperLibraryInfo), iterator
        );
        iterator = ArraysLibrary.insert(calls_, CurveLibrary.getCurveCalls(curveLibraryInfo), iterator);

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}

library mAlphaLibrary {
    function getSubvault0Proofs(address curator, address subvault)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            allowed assets: usdc
            1. morpho deposit
            2. bracket deposit
            3. cowswap (usdc, usdu)
            4. curve usdc, usdu
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);

        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            WethLibrary.getWethProofs(bitmaskVerifier, WethLibrary.Info({curator: curator, weth: Constants.WETH})),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.WETH, Constants.USDC, Constants.USDU, Constants.USDT)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            ERC4626Library.getERC4626Proofs(
                bitmaskVerifier,
                ERC4626Library.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.MORPHO_USDC_ALPHAPING, Constants.MORPHO_WETH_ALPHAPING)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            BracketVaultLibrary.getBracketVaultProofs(
                bitmaskVerifier,
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_USDC_VAULT
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            BracketVaultLibrary.getBracketVaultProofs(
                bitmaskVerifier,
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_WETH_VAULT
                })
            ),
            iterator
        );

        iterator = ArraysLibrary.insert(
            leaves,
            CurveLibrary.getCurveProofs(
                bitmaskVerifier,
                CurveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
                })
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);

        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            WethLibrary.getWethDescriptions(WethLibrary.Info({curator: curator, weth: Constants.WETH})),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.WETH, Constants.USDC, Constants.USDU, Constants.USDT)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            ERC4626Library.getERC4626Descriptions(
                ERC4626Library.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.MORPHO_USDC_ALPHAPING, Constants.MORPHO_WETH_ALPHAPING)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            BracketVaultLibrary.getBracketVaultDescriptions(
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_USDC_VAULT
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions,
            BracketVaultLibrary.getBracketVaultDescriptions(
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_WETH_VAULT
                })
            ),
            iterator
        );

        iterator = ArraysLibrary.insert(
            descriptions,
            CurveLibrary.getCurveDescriptions(
                CurveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
                })
            ),
            iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](50);

        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls_, WethLibrary.getWethCalls(WethLibrary.Info({curator: curator, weth: Constants.WETH})), iterator
        );
        iterator = ArraysLibrary.insert(
            calls_,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.WETH, Constants.USDC, Constants.USDU, Constants.USDT)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls_,
            ERC4626Library.getERC4626Calls(
                ERC4626Library.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.MORPHO_USDC_ALPHAPING, Constants.MORPHO_WETH_ALPHAPING)
                    )
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls_,
            BracketVaultLibrary.getBracketVaultCalls(
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_USDC_VAULT
                })
            ),
            iterator
        );
        iterator = ArraysLibrary.insert(
            calls_,
            BracketVaultLibrary.getBracketVaultCalls(
                BracketVaultLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    vault: Constants.BRACKET_FINANCE_WETH_VAULT
                })
            ),
            iterator
        );

        iterator = ArraysLibrary.insert(
            calls_,
            CurveLibrary.getCurveCalls(
                CurveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault0",
                    curator: curator,
                    pool: Constants.CURVE_USDC_USDU_POOL,
                    gauge: Constants.CURVE_USDC_USDU_GAUGE
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
