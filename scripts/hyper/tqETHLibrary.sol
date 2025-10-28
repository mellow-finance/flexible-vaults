// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {HyperLiquidLibrary} from "../common/protocols/HyperLiquidLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

library tqETHLibrary {
    function getInfo(address strategy) internal pure returns (HyperLiquidLibrary.Info memory) {
        uint24[] memory actions = ArraysLibrary.makeUint24Array(
            abi.encode(
                HyperLiquidLibrary.LIMIT_ORDER,
                HyperLiquidLibrary.SPOT_SEND,
                HyperLiquidLibrary.USD_CLASS_TRANSFER,
                HyperLiquidLibrary.CANCEL_ORDER_BY_OID,
                HyperLiquidLibrary.CANCEL_ORDER_BY_CLOID
            )
        );
        HyperLiquidLibrary.Token[] memory tokens = new HyperLiquidLibrary.Token[](1);
        tokens[0] = HyperLiquidLibrary.Token({
            addr: 0xa9056c15938f9aff34CD497c722Ce33dB0C2fD57, // PURR
            id: 1,
            assets: ArraysLibrary.makeUint32Array(abi.encode(0)) // PURR/USDC
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
                vaults: new address[](0),
                validators: new address[](0),
                apiWallets: new address[](0)
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
        leaves = HyperLiquidLibrary.getHyperLiquidProofs($.bitmaskVerifier, getInfo(strategy));

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address strategy) internal view returns (string[] memory descriptions) {
        descriptions = HyperLiquidLibrary.getHyperLiquidDescription(getInfo(strategy));
        return descriptions;
    }

    function getSubvault0SubvaultCalls(address strategy, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        calls.calls[0] = HyperLiquidLibrary.getHyperLiquidCalls(getInfo(strategy));
    }
}
