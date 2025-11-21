// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";

import "./Constants.sol";

library monLibrary {
    using ArraysLibrary for IVerifier.VerificationPayload[];
    using ArraysLibrary for string[];
    using ArraysLibrary for Call[][];

    struct Info {
        address subvault;
        string subvaultName;
        address curator;
        address aaveInstance;
        string aaveInstanceName;
        address[] collaterals;
        address[] loans;
    }

    function getSubvault0Proofs(Info memory $)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        /*
            1. weth.deposit{value: <any>}();
            2. weth.withdraw(<any>);
            3. aave proofs
        */
        uint256 iterator;
        leaves = new IVerifier.VerificationPayload[](50);
        leaves[iterator++] =
            WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info($.curator, Constants.WETH));
        leaves[iterator++] =
            WethLibrary.getWethWithdrawProof(bitmaskVerifier, WethLibrary.Info($.curator, Constants.WETH));
        iterator = leaves.insert(
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: $.aaveInstance,
                    aaveInstanceName: $.aaveInstanceName,
                    collaterals: $.collaterals,
                    loans: $.loans,
                    categoryId: 1
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
        uint256 iterator;
        descriptions = new string[](50);
        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info($.curator, Constants.WETH));
        descriptions[iterator++] = WethLibrary.getWethWithdrawDescription(WethLibrary.Info($.curator, Constants.WETH));
        iterator = descriptions.insert(
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: $.aaveInstance,
                    aaveInstanceName: $.aaveInstanceName,
                    collaterals: $.collaterals,
                    loans: $.loans,
                    categoryId: 1
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
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        calls.calls[0] = WethLibrary.getWethDepositCalls(WethLibrary.Info($.curator, Constants.WETH));
        calls.calls[1] = WethLibrary.getWethWithdrawCalls(WethLibrary.Info($.curator, Constants.WETH));
        calls.calls.insert(
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: $.subvault,
                    subvaultName: $.subvaultName,
                    curator: $.curator,
                    aaveInstance: $.aaveInstance,
                    aaveInstanceName: $.aaveInstanceName,
                    collaterals: $.collaterals,
                    loans: $.loans,
                    categoryId: 1
                })
            ),
            2
        );
    }
}
