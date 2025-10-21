// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";

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

    function getSubvault0SubvaultCalls(
        ProtocolDeployment memory $,
        address curator,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
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
}

library tqETHLibraryV2 {
    function getSubvault0Proofs(address curator, address agent)
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
        leaves = new IVerifier.VerificationPayload[](12);
        leaves[0] = WethLibrary.getWethDepositProof($.bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
        leaves[1] = WethLibrary.getWethWithdrawProof($.bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));

        leaves[2] = WethLibrary.getWethDepositProof($.bitmaskVerifier, WethLibrary.Info(agent, Constants.WETH));
        leaves[3] = WethLibrary.getWethWithdrawProof($.bitmaskVerifier, WethLibrary.Info(agent, Constants.WETH));

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
            4
        );
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                $.bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: agent,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            8
        );
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address agent)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](12);
        descriptions[0] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        descriptions[1] = WethLibrary.getWethWithdrawDescription(WethLibrary.Info(curator, Constants.WETH));

        descriptions[2] = WethLibrary.getWethDepositDescription(WethLibrary.Info(agent, Constants.WETH));
        descriptions[3] = WethLibrary.getWethWithdrawDescription(WethLibrary.Info(agent, Constants.WETH));
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
            4
        );
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: agent,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            8
        );
    }

    function getSubvault0SubvaultCalls(
        ProtocolDeployment memory $,
        address curator,
        address agent,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        calls.calls[0] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        calls.calls[1] = WethLibrary.getWethWithdrawCalls(WethLibrary.Info(curator, Constants.WETH));

        calls.calls[2] = WethLibrary.getWethDepositCalls(WethLibrary.Info(agent, Constants.WETH));
        calls.calls[3] = WethLibrary.getWethWithdrawCalls(WethLibrary.Info(agent, Constants.WETH));
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
            4
        );
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: agent,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            8
        );
    }
}
