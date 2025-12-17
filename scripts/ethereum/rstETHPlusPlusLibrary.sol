// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {Constants} from "./Constants.sol";

library rstETHPlusPlusLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function _getSubvault0SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault0",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(
                abi.encode(Constants.ETH, Constants.WETH, Constants.RSETH, Constants.WSTETH, Constants.WEETH)
            )
        });
    }

    function getSubvault0Proofs(address curator, address subvault, address swapModule)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault0SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault0SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0Calls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault0SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
    }

    function _getSubvault1AaveCoreParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WEETH, Constants.RSETH, Constants.WSTETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 1
        });
    }

    function _getSubvault1AavePrimeParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator,
            aaveInstance: Constants.AAVE_PRIME,
            aaveInstanceName: "Prime",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH, Constants.RSETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
            categoryId: 1
        });
    }

    function getSubvault1Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves, AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault1AavePrimeParams(curator, subvault)),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault1AavePrimeParams(curator, subvault)), iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1Calls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault1AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault1AavePrimeParams(curator, subvault)), iterator
        );
    }

    function _getSubvault2AaveCoreParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault2",
            curator: curator,
            aaveInstance: Constants.AAVE_CORE,
            aaveInstanceName: "Core",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.RSETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            categoryId: 3
        });
    }

    function _getSubvault2AavePrimeParams(address curator, address subvault)
        internal
        pure
        returns (AaveLibrary.Info memory)
    {
        return AaveLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault2",
            curator: curator,
            aaveInstance: Constants.AAVE_PRIME,
            aaveInstanceName: "Prime",
            collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.RSETH)),
            loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
            categoryId: 5
        });
    }

    function getSubvault2Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](50);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            leaves, AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault2AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(bitmaskVerifier, _getSubvault2AavePrimeParams(curator, subvault)),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault2Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](50);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault2AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            descriptions, AaveLibrary.getAaveDescriptions(_getSubvault2AavePrimeParams(curator, subvault)), iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault2Calls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault2AaveCoreParams(curator, subvault)), iterator
        );
        iterator = ArraysLibrary.insert(
            calls.calls, AaveLibrary.getAaveCalls(_getSubvault2AavePrimeParams(curator, subvault)), iterator
        );
    }
}
