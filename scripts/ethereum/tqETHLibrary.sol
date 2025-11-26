// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CoreVaultLibrary} from "../common/protocols/CoreVaultLibrary.sol";

import {StakeWiseLibrary} from "../common/protocols/StakeWiseLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

library tqETHLibrary {
    function getSubvault0Info(address subvault, address[] memory curators, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault0",
            swapModule: swapModule,
            curators: curators,
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH))
        });
    }

    function getSubvault0Proofs(address subvault, address swapModule, address[] memory curators)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs($.bitmaskVerifier, getSubvault0Info(subvault, curators, swapModule)),
            iterator
        );
        assembly {
            mstore(leaves, iterator)
        }
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address subvault, address swapModule, address[] memory curators)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(getSubvault0Info(subvault, curators, swapModule)),
            iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(
        address subvault,
        address swapModule,
        address[] memory curators,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(getSubvault0Info(subvault, curators, swapModule)),
            iterator
        );
    }

    function getSubvault1CoreVaultInfo(address subvault, address[] memory curators)
        internal
        pure
        returns (CoreVaultLibrary.Info[] memory data)
    {
        address[] memory depositQueues = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.STRETH_DEPOSIT_QUEUE_ETH,
                Constants.STRETH_DEPOSIT_QUEUE_WETH,
                Constants.STRETH_DEPOSIT_QUEUE_WSTETH
            )
        );
        address[] memory redeemQueues = ArraysLibrary.makeAddressArray(abi.encode(Constants.STRETH_REDEEM_QUEUE_WSTETH));
        data = new CoreVaultLibrary.Info[](curators.length);
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = CoreVaultLibrary.Info({
                subvault: subvault,
                subvaultName: "subvault1",
                curator: curators[i],
                vault: Constants.STRETH,
                depositQueues: depositQueues,
                redeemQueues: redeemQueues
            });
        }
    }

    function getSubvault1Proofs(address subvault, address[] memory curators)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](50);
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        uint256 iterator = 0;
        CoreVaultLibrary.Info[] memory data = getSubvault1CoreVaultInfo(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator =
                ArraysLibrary.insert(leaves, CoreVaultLibrary.getCoreVaultProofs($.bitmaskVerifier, data[i]), iterator);
        }
        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address subvault, address[] memory curators)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        CoreVaultLibrary.Info[] memory data = getSubvault1CoreVaultInfo(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator = ArraysLibrary.insert(descriptions, CoreVaultLibrary.getCoreVaultDescriptions(data[i]), iterator);
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1SubvaultCalls(
        address subvault,
        address[] memory curators,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        CoreVaultLibrary.Info[] memory data = getSubvault1CoreVaultInfo(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator = ArraysLibrary.insert(calls.calls, CoreVaultLibrary.getCoreVaultCalls(data[i]), iterator);
        }
    }

    function getSubvault2Info(address subvault, address[] memory curators)
        internal
        pure
        returns (StakeWiseLibrary.Info[] memory data)
    {
        data = new StakeWiseLibrary.Info[](curators.length);
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = StakeWiseLibrary.Info({
                curator: curators[i],
                subvault: subvault,
                subvaultName: "subvault2",
                vault: 0xe6d8d8aC54461b1C5eD15740EEe322043F696C08,
                vaultName: "Chorus One - MEV Max"
            });
        }
    }

    function getSubvault2Proofs(address subvault, address[] memory curators)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        ProtocolDeployment memory $ = Constants.protocolDeployment();
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        StakeWiseLibrary.Info[] memory data = getSubvault2Info(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator =
                ArraysLibrary.insert(leaves, StakeWiseLibrary.getStakeWiseProofs($.bitmaskVerifier, data[i]), iterator);
        }
        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault2Descriptions(address subvault, address[] memory curators)
        internal
        pure
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        StakeWiseLibrary.Info[] memory data = getSubvault2Info(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator = ArraysLibrary.insert(descriptions, StakeWiseLibrary.getStakeWiseDescriptions(data[i]), iterator);
        }
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault2SubvaultCalls(
        address subvault,
        address[] memory curators,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        StakeWiseLibrary.Info[] memory data = getSubvault2Info(subvault, curators);
        for (uint256 i = 0; i < data.length; i++) {
            iterator = ArraysLibrary.insert(calls.calls, StakeWiseLibrary.getStakeWiseCalls(data[i]), iterator);
        }
    }
}
