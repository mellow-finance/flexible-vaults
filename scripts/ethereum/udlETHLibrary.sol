// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CapLenderLibrary} from "../common/protocols/CapLenderLibrary.sol";

import {SymbioticLibrary} from "../common/protocols/SymbioticLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library udlETHLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address curator;
        address subvault;
        address capSymbioticVault;
    }

    function getSubvault0Proofs(Info memory $)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{any}()
            2. cowswap proofs for weth -> wsteth
            3. capSymbioticVault proofs for subvault
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;

        leaves[iterator++] =
            WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info($.curator, Constants.WETH));

        iterator = leaves.insert(
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        iterator = leaves.insert(
            SymbioticLibrary.getSymbioticProofs(
                bitmaskVerifier,
                SymbioticLibrary.Info({
                    symbioticVault: $.capSymbioticVault,
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator
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

        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info($.curator, Constants.WETH));

        iterator = descriptions.insert(
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        iterator = descriptions.insert(
            SymbioticLibrary.getSymbioticDescriptions(
                SymbioticLibrary.Info({
                    symbioticVault: $.capSymbioticVault,
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator
                })
            ),
            iterator
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
        Call[][] memory calls_ = new Call[][](leaves.length);
        uint256 iterator = 0;

        calls_[iterator++] = WethLibrary.getWethDepositCalls(WethLibrary.Info($.curator, Constants.WETH));
        iterator = calls_.insert(
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: $.curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        iterator = calls_.insert(
            SymbioticLibrary.getSymbioticCalls(
                SymbioticLibrary.Info({
                    symbioticVault: $.capSymbioticVault,
                    subvault: $.subvault,
                    subvaultName: "subvault0",
                    curator: $.curator
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
