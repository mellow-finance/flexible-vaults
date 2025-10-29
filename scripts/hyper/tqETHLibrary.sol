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

    function getHypeTokenIndex() internal view returns (uint32) {
        if (block.chainid == 999) {
            return 0x451;
        } else if (block.chainid == 998) {
            return 0x451;
        } else {
            revert("Unsupported chainid for HYPE token index");
        }
    }

    function getHyperLiquidInfo(address strategy) internal view returns (HyperLiquidLibrary.Info memory) {
        uint24[] memory actions = ArraysLibrary.makeUint24Array(
            abi.encode(
                HyperLiquidLibrary.LIMIT_ORDER,
                HyperLiquidLibrary.SPOT_SEND,
                HyperLiquidLibrary.USD_CLASS_TRANSFER,
                HyperLiquidLibrary.CANCEL_ORDER_BY_OID,
                HyperLiquidLibrary.CANCEL_ORDER_BY_CLOID /*,
                HyperLiquidLibrary.VAULT_TRANSFER,
                HyperLiquidLibrary.TOKEN_DELEGATE,
                HyperLiquidLibrary.STAKING_DEPOSIT,
                HyperLiquidLibrary.STAKING_WITHDRAW,
                HyperLiquidLibrary.FINALIZE_EVM_CONTRACT,
                HyperLiquidLibrary.ADD_API_WALLET */
            )
        );

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
            hypeTokenIndex: getHypeTokenIndex(),
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
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        /*
            0. IERC20.approve(tokenMessenger, any);
            1. ITokenMessengerV2.depositForBurn(any, destinationDomain, mintRecipient, burnToken, bytes32(0), any, any);
            2. hype.call{value: any}("") deposits HYPE to Core
            3. withdraw Hype to EVM
            4. token.transfer(systemAddress, any) deposits ERC20 to Core
            5. coreWriter.sendRawAction(actions + any params)
        */
        uint256 coreActions = HyperLiquidLibrary.getTotalActionsCount(getHyperLiquidInfo(strategy));
        uint256 cctpActions = 2;
        leaves = new IVerifier.VerificationPayload[](coreActions + cctpActions);
        uint256 iterator = ArraysLibrary.insert(
            leaves, CircleBridgeLibrary.getCctpV2BridgeProofs($.bitmaskVerifier, getCctpInfo(strategy)), 0
        );
        ArraysLibrary.insert(
            leaves, HyperLiquidLibrary.getHyperLiquidProofs($.bitmaskVerifier, getHyperLiquidInfo(strategy)), iterator
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address strategy) internal view returns (string[] memory descriptions) {
        uint256 coreActions = HyperLiquidLibrary.getTotalActionsCount(getHyperLiquidInfo(strategy));
        uint256 cctpActions = 2;
        descriptions = new string[](coreActions + cctpActions);

        uint256 iterator = ArraysLibrary.insert(
            descriptions, CircleBridgeLibrary.getCctpV2BridgeDescriptions(getCctpInfo(strategy)), 0
        );
        ArraysLibrary.insert(
            descriptions, HyperLiquidLibrary.getHyperLiquidDescription(getHyperLiquidInfo(strategy)), iterator
        );
        return descriptions;
    }

    function getSubvault0SubvaultCalls(address strategy, IVerifier.VerificationPayload[] memory leaves)
        internal
        view
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        uint256 iterator =
            ArraysLibrary.insert(calls.calls, CircleBridgeLibrary.getCctpV2BridgeCalls(getCctpInfo(strategy)), 0);
        ArraysLibrary.insert(
            calls.calls, HyperLiquidLibrary.getHyperLiquidCalls(getHyperLiquidInfo(strategy)), iterator
        );
    }
}
