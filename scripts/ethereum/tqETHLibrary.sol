// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CoreVaultLibrary} from "../common/protocols/CoreVaultLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
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

    function getSubvault1CoreVaultInfo(address subvault, address curator)
        internal
        view
        returns (CoreVaultLibrary.Info memory)
    {
        address[] memory depositQueues = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.STRETH_DEPOSIT_QUEUE_ETH,
                Constants.STRETH_DEPOSIT_QUEUE_WETH,
                Constants.STRETH_DEPOSIT_QUEUE_WSTETH
            )
        );
        address[] memory redeemQueues = ArraysLibrary.makeAddressArray(abi.encode(Constants.STRETH_REDEEM_QUEUE_WSTETH));
        return CoreVaultLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator,
            vault: Constants.STRETH,
            depositQueues: depositQueues,
            redeemQueues: redeemQueues
        });
    }

    function getSubvault1Proofs(address subvault, address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            CoreVaultLibrary.getCoreVaultProofs($.bitmaskVerifier, getSubvault1CoreVaultInfo(subvault, curator)),
            iterator
        );
        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address subvault, address curator)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            CoreVaultLibrary.getCoreVaultDescriptions(getSubvault1CoreVaultInfo(subvault, curator)),
            iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1SubvaultCalls(address subvault, address curator, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        ArraysLibrary.insert(
            calls.calls, CoreVaultLibrary.getCoreVaultCalls(getSubvault1CoreVaultInfo(subvault, curator)), 0
        );
    }
}
