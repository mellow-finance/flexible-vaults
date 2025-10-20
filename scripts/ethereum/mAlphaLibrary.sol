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

import {BracketVaultLibrary} from "../common/protocols/BracketVaultLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {CurveLibrary} from "../common/protocols/CurveLibrary.sol";
import {ERC20Library} from "../common/protocols/ERC20Library.sol";
import {ERC4626Library} from "../common/protocols/ERC4626Library.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";
import {Constants} from "./Constants.sol";

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
