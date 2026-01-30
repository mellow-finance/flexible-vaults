// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";

import {CoreVaultLibrary} from "../common/protocols/CoreVaultLibrary.sol";

import "./Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library earnUSDLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function _getSubvaultCoreVaultParams(address curator, address subvault, string memory subvaultName, address vault_)
        internal
        view
        returns (CoreVaultLibrary.Info memory)
    {
        Vault vault = Vault(payable(vault_));
        uint256 totalQueues = vault.getQueueCount();
        address[] memory depositQueues = new address[](totalQueues);
        address[] memory redeemQueues = new address[](totalQueues);
        uint256 depositQueueIterator = 0;
        uint256 redeemQueueIterator = 0;
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    depositQueues[depositQueueIterator++] = queue;
                } else {
                    redeemQueues[redeemQueueIterator++] = queue;
                }
            }
        }
        assembly {
            mstore(depositQueues, depositQueueIterator)
            mstore(redeemQueues, redeemQueueIterator)
        }

        return CoreVaultLibrary.Info({
            subvault: subvault,
            subvaultName: subvaultName,
            curator: curator,
            vault: vault_,
            depositQueues: depositQueues,
            redeemQueues: redeemQueues
        });
    }

    function getSubvault0Proofs(address curator, address subvault, address vault)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            CoreVaultLibrary.getCoreVaultProofs(
                bitmaskVerifier, _getSubvaultCoreVaultParams(curator, subvault, "subvault0", vault)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault, address vault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            CoreVaultLibrary.getCoreVaultDescriptions(
                _getSubvaultCoreVaultParams(curator, subvault, "subvault0", vault)
            ),
            iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(
        address curator,
        address subvault,
        address vault,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls.calls,
            CoreVaultLibrary.getCoreVaultCalls(_getSubvaultCoreVaultParams(curator, subvault, "subvault0", vault)),
            iterator
        );
    }

    function getSubvault1Proofs(address curator, address subvault, address vault)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            CoreVaultLibrary.getCoreVaultProofs(
                bitmaskVerifier, _getSubvaultCoreVaultParams(curator, subvault, "subvault1", vault)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault, address vault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            CoreVaultLibrary.getCoreVaultDescriptions(
                _getSubvaultCoreVaultParams(curator, subvault, "subvault1", vault)
            ),
            iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1SubvaultCalls(
        address curator,
        address subvault,
        address vault,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls.calls,
            CoreVaultLibrary.getCoreVaultCalls(_getSubvaultCoreVaultParams(curator, subvault, "subvault1", vault)),
            iterator
        );
    }
}
