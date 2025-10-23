// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";

import {CircleBridgeLibrary} from "../common/protocols/CircleBridgeLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

library tqETHLibrary {
    function getSubvault0Proofs(address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            1. weth.deposit{value: <any>}();
            2. weth.withdraw(<any>);
            3. weth.approve(cowswapVaultRelayer, <any>);
            4. wsteth.approve(cowswapVaultRelayer, <any>);
            5. cowswapSettlement.setPreSignature(anyBytes(56), anyBool);
            6. cowswapSettlement.invalidateOrder(anyBytes(56)); 
        */
        leaves = new IVerifier.VerificationPayload[](6);
        leaves[0] = WethLibrary.getWethDepositProof($.bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
        leaves[1] = WethLibrary.getWethWithdrawProof($.bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));

        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                $.bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            2
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator) internal view returns (string[] memory descriptions) {
        descriptions = new string[](6);
        descriptions[0] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        descriptions[1] = WethLibrary.getWethWithdrawDescription(WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            2
        );
    }

    function getSubvault0SubvaultCalls(address curator, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        calls.calls[0] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        calls.calls[1] = WethLibrary.getWethWithdrawCalls(WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            2
        );
    }

    function getSubvault1Proofs(address curator, address strategy)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            1. weth.approve(cowswapVaultRelayer, <any>);
            2. wsteth.approve(cowswapVaultRelayer, <any>);
            3. usdc.approve(cowswapVaultRelayer, <any>);
            4. cowswapSettlement.setPreSignature(anyBytes(56), anyBool);
            5. cowswapSettlement.invalidateOrder(anyBytes(56));
            6. IERC20.approve(tokenMessenger, any);
            7. ITokenMessengerV2.depositForBurn(any, destinationDomain, mintRecipient, burnToken, bytes32(0), any, any);
        */
        leaves = new IVerifier.VerificationPayload[](7);

        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                $.bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH, Constants.USDC))
                })
            ),
            0
        );

        ArraysLibrary.insert(
            leaves,
            CircleBridgeLibrary.getCctpV2BridgeProofs(
                $.bitmaskVerifier,
                CircleBridgeLibrary.Info({
                    strategy: strategy,
                    tokenMessenger: Constants.TOKEN_MESSENGER_SEPOLIA,
                    destinationSubvault: Constants.DESTINATION_SUBVAULT_HYPER,
                    destinationDomain: Constants.DESTINATION_DOMAIN_HYPER,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC))
                })
            ),
            5
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address strategy)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](7);
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH, Constants.USDC))
                })
            ),
            0
        );

        ArraysLibrary.insert(
            descriptions,
            CircleBridgeLibrary.getCctpV2BridgeDescriptions(
                CircleBridgeLibrary.Info({
                    strategy: strategy,
                    tokenMessenger: Constants.TOKEN_MESSENGER_SEPOLIA,
                    destinationSubvault: Constants.DESTINATION_SUBVAULT_HYPER,
                    destinationDomain: Constants.DESTINATION_DOMAIN_HYPER,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC))
                })
            ),
            5
        );
    }

    function getSubvault1SubvaultCalls(address curator, address strategy, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH, Constants.USDC))
                })
            ),
            0
        );

        ArraysLibrary.insert(
            calls.calls,
            CircleBridgeLibrary.getCctpV2BridgeCalls(
                CircleBridgeLibrary.Info({
                    strategy: strategy,
                    tokenMessenger: Constants.TOKEN_MESSENGER_SEPOLIA,
                    destinationSubvault: Constants.DESTINATION_SUBVAULT_HYPER,
                    destinationDomain: Constants.DESTINATION_DOMAIN_HYPER,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC))
                })
            ),
            5
        );
    }
}
