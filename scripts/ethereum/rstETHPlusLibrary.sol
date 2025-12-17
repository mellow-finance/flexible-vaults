// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
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

import {CapLenderLibrary} from "../common/protocols/CapLenderLibrary.sol";
import {MorphoLibrary} from "../common/protocols/MorphoLibrary.sol";
import {ResolvLibrary} from "../common/protocols/ResolvLibrary.sol";
import {SwapModuleLibrary} from "../common/protocols/SwapModuleLibrary.sol";
import {SymbioticLibrary} from "../common/protocols/SymbioticLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {Constants} from "./Constants.sol";

library rstETHPlusLibrary {
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
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
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
        leaves[iterator++] = WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
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
        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
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
        calls.calls[iterator++] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            calls.calls,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault0SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );
    }

    function _getSubvault1SymbioticParams(address curator, address subvault, address symbioticVault)
        internal
        pure
        returns (SymbioticLibrary.Info memory)
    {
        return SymbioticLibrary.Info({
            symbioticVault: symbioticVault,
            subvault: subvault,
            subvaultName: "subvault1",
            curator: curator
        });
    }

    function getSubvault1Proofs(address curator, address subvault, address capSymbioticVault)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](8);
        uint256 iterator = 0;
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        iterator = ArraysLibrary.insert(
            leaves,
            SymbioticLibrary.getSymbioticProofs(
                bitmaskVerifier, _getSubvault1SymbioticParams(curator, subvault, capSymbioticVault)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault, address capSymbioticVault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](8);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            SymbioticLibrary.getSymbioticDescriptions(
                _getSubvault1SymbioticParams(curator, subvault, capSymbioticVault)
            ),
            iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault1Calls(
        address curator,
        address subvault,
        address capSymbioticVault,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            calls.calls,
            SymbioticLibrary.getSymbioticCalls(_getSubvault1SymbioticParams(curator, subvault, capSymbioticVault)),
            iterator
        );
    }

    function _getSubvault2CapLenderParams(address curator, address subvault)
        internal
        pure
        returns (CapLenderLibrary.Info memory)
    {
        return CapLenderLibrary.Info({
            asset: Constants.USDC,
            lender: Constants.CAP_LENDER,
            subvault: subvault,
            subvaultName: "subvault2",
            curator: curator
        });
    }

    function _getSubvault2ResolvParams(address curator, address subvault)
        internal
        pure
        returns (ResolvLibrary.Info memory)
    {
        return ResolvLibrary.Info({
            asset: Constants.USDC,
            usrRequestManager: Constants.USR_REQUEST_MANAGER,
            usr: Constants.USR,
            wstUSR: Constants.WSTUSR,
            subvault: subvault,
            subvaultName: "subvault2",
            curator: curator
        });
    }

    function _getSubvault2MorphoParams(address curator, address subvault)
        internal
        pure
        returns (MorphoLibrary.Info memory)
    {
        return MorphoLibrary.Info({
            marketId: Constants.MORPHO_WSTUSR_USDC_MARKET_ID,
            morpho: Constants.MORPHO,
            subvault: subvault,
            curator: curator
        });
    }

    function _getSubvault2SwapModuleParams(address curator, address subvault, address swapModule)
        internal
        pure
        returns (SwapModuleLibrary.Info memory)
    {
        return SwapModuleLibrary.Info({
            subvault: subvault,
            subvaultName: "subvault2",
            swapModule: swapModule,
            curators: ArraysLibrary.makeAddressArray(abi.encode(curator)),
            assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH, Constants.USDC))
        });
    }

    function getSubvault2Proofs(address curator, address subvault, address swapModule)
        internal
        view
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        leaves = new IVerifier.VerificationPayload[](42);
        uint256 iterator = 0;

        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        iterator = ArraysLibrary.insert(
            leaves,
            CapLenderLibrary.getCapLenderProofs(bitmaskVerifier, _getSubvault2CapLenderParams(curator, subvault)),
            iterator
        );

        iterator = ArraysLibrary.insert(
            leaves,
            ResolvLibrary.getResolvProofs(bitmaskVerifier, _getSubvault2ResolvParams(curator, subvault)),
            iterator
        );

        iterator = ArraysLibrary.insert(
            leaves,
            MorphoLibrary.getMorphoProofs(bitmaskVerifier, _getSubvault2MorphoParams(curator, subvault)),
            iterator
        );

        iterator = ArraysLibrary.insert(
            leaves,
            SwapModuleLibrary.getSwapModuleProofs(
                bitmaskVerifier, _getSubvault2SwapModuleParams(curator, subvault, swapModule)
            ),
            iterator
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault2Descriptions(address curator, address subvault, address swapModule)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](42);
        uint256 iterator = 0;
        iterator = ArraysLibrary.insert(
            descriptions,
            CapLenderLibrary.getCapLenderDescriptions(_getSubvault2CapLenderParams(curator, subvault)),
            iterator
        );

        iterator = ArraysLibrary.insert(
            descriptions, ResolvLibrary.getResolvDescriptions(_getSubvault2ResolvParams(curator, subvault)), iterator
        );

        iterator = ArraysLibrary.insert(
            descriptions, MorphoLibrary.getMorphoDescriptions(_getSubvault2MorphoParams(curator, subvault)), iterator
        );

        iterator = ArraysLibrary.insert(
            descriptions,
            SwapModuleLibrary.getSwapModuleDescriptions(_getSubvault2SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault2Calls(
        address curator,
        address subvault,
        address swapModule,
        IVerifier.VerificationPayload[] memory leaves
    ) internal view returns (SubvaultCalls memory calls) {
        calls.payloads = leaves;
        Call[][] memory calls_ = new Call[][](leaves.length);
        uint256 iterator = 0;

        iterator = ArraysLibrary.insert(
            calls_, CapLenderLibrary.getCapLenderCalls(_getSubvault2CapLenderParams(curator, subvault)), iterator
        );

        iterator = ArraysLibrary.insert(
            calls_, ResolvLibrary.getResolvCalls(_getSubvault2ResolvParams(curator, subvault)), iterator
        );

        iterator = ArraysLibrary.insert(
            calls_, MorphoLibrary.getMorphoCalls(_getSubvault2MorphoParams(curator, subvault)), iterator
        );

        iterator = ArraysLibrary.insert(
            calls_,
            SwapModuleLibrary.getSwapModuleCalls(_getSubvault2SwapModuleParams(curator, subvault, swapModule)),
            iterator
        );

        assembly {
            mstore(calls_, iterator)
        }

        calls.calls = calls_;
    }
}
