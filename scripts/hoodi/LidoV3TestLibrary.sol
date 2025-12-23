// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {LidoV3Library} from "../common/protocols/LidoV3Library.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library LidoV3TestLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function _getSubvault0LidoV3VaultParams(address curator, address subvault, address dashboard)
        internal
        pure
        returns (LidoV3Library.Info memory)
    {
        return LidoV3Library.Info({
            wsteth: Constants.WSTETH,
            curator: curator,
            subvault: subvault,
            subvaultName: "subvault0",
            dashboard: dashboard,
            dashboardName: "test LidoV3 dashboard"
        });
    }

    function getSubvault0Proofs(address curator, address subvault, address dashboard)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            LidoV3Library.getLidoV3Proofs(bitmaskVerifier, _getSubvault0LidoV3VaultParams(curator, subvault, dashboard)),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault, address dashboard)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            LidoV3Library.getLidoV3Descriptions(_getSubvault0LidoV3VaultParams(curator, subvault, dashboard)),
            iterator
        );
        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(
        address curator,
        address subvault,
        address dashboard,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls.calls,
            LidoV3Library.getLidoV3Calls(_getSubvault0LidoV3VaultParams(curator, subvault, dashboard)),
            iterator
        );
    }
}
