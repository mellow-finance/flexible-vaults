// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CircleBridgeLibrary} from "../common/protocols/CircleBridgeLibrary.sol";
import {HyperLiquidLibrary} from "../common/protocols/HyperLiquidLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

library tqETHLibrary {
    function getCctpInfo(address strategy) internal pure returns (CircleBridgeLibrary.Info memory) {
        return CircleBridgeLibrary.Info({
            strategy: strategy,
            tokenMessenger: Constants.TOKEN_MESSENGER_HYPER,
            destinationSubvault: Constants.DESTINATION_SUBVAULT_SEPOLIA,
            destinationDomain: Constants.DESTINATION_DOMAIN_SEPOLIA,
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC))
        });
    }

    function getHyperLiquidInfo(address strategy) internal pure returns (HyperLiquidLibrary.Info memory) {
        uint24[] memory actions = ArraysLibrary.makeUint24Array(
            abi.encode(
                HyperLiquidLibrary.LIMIT_ORDER,
                HyperLiquidLibrary.SPOT_SEND,
                HyperLiquidLibrary.USD_CLASS_TRANSFER,
                HyperLiquidLibrary.CANCEL_ORDER_BY_OID,
                HyperLiquidLibrary.CANCEL_ORDER_BY_CLOID
            )
        );
        //HyperLiquidLibrary.VAULT_TRANSFER,
        //HyperLiquidLibrary.TOKEN_DELEGATE,
        //HyperLiquidLibrary.STAKING_DEPOSIT,
        //HyperLiquidLibrary.STAKING_WITHDRAW,
        //HyperLiquidLibrary.FINALIZE_EVM_CONTRACT,
        //HyperLiquidLibrary.ADD_API_WALLET

        HyperLiquidLibrary.Token[] memory tokens = new HyperLiquidLibrary.Token[](2);
        tokens[0] = HyperLiquidLibrary.Token({
            addr: 0xa9056c15938f9aff34CD497c722Ce33dB0C2fD57, // PURR
            id: 1,
            assets: ArraysLibrary.makeUint32Array(abi.encode(123, 456)) //
        });

        tokens[1] = HyperLiquidLibrary.Token({
            addr: 0x453b63484b11bbF0b61fC7E854f8DAC7bdE7d458, // MBTC
            id: 2,
            assets: ArraysLibrary.makeUint32Array(abi.encode(321, 654)) //
        });

        return HyperLiquidLibrary.Info({
            strategy: strategy,
            hype: Constants.HYPE,
            core: Constants.CORE,
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC)),
            systemAddress: Constants.USDC,
            version: 0x01,
            params: HyperLiquidLibrary.ActionParams({
                actions: actions,
                tokens: tokens,
                vaults: new address[](2),
                validators: new address[](3),
                apiWallets: new address[](4)
            })
        });
    }

    function getSubvault0Proofs(address strategy)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            0. hype.call{value: any}("") send to core
            1. coreWriter.sendRawAction(<version 0x01, Only actions 1,6,7,10,11 supported>)
        */
        uint256 coreActions = HyperLiquidLibrary.getTotalActionsCount(getHyperLiquidInfo(strategy));
        uint256 cctpActions = 2;
        leaves = new IVerifier.VerificationPayload[](coreActions + cctpActions);
        ArraysLibrary.insert(
            leaves, CircleBridgeLibrary.getCctpV2BridgeProofs($.bitmaskVerifier, getCctpInfo(strategy)), 0
        );
        ArraysLibrary.insert(
            leaves,
            HyperLiquidLibrary.getHyperLiquidProofs($.bitmaskVerifier, getHyperLiquidInfo(strategy)),
            cctpActions
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address strategy) internal view returns (string[] memory descriptions) {
        uint256 coreActions = HyperLiquidLibrary.getTotalActionsCount(getHyperLiquidInfo(strategy));
        uint256 cctpActions = 2;
        descriptions = new string[](coreActions + cctpActions);
        ArraysLibrary.insert(descriptions, CircleBridgeLibrary.getCctpV2BridgeDescriptions(getCctpInfo(strategy)), 0);
        ArraysLibrary.insert(
            descriptions, HyperLiquidLibrary.getHyperLiquidDescription(getHyperLiquidInfo(strategy)), cctpActions
        );
        return descriptions;
    }

    function getSubvault0SubvaultCalls(address strategy, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        ArraysLibrary.insert(calls.calls, CircleBridgeLibrary.getCctpV2BridgeCalls(getCctpInfo(strategy)), 0);
        ArraysLibrary.insert(calls.calls, HyperLiquidLibrary.getHyperLiquidCalls(getHyperLiquidInfo(strategy)), 2);
    }
}
