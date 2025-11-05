// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ABILibrary} from "../common/ABILibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {JsonLibrary} from "../common/JsonLibrary.sol";
import {ParameterLibrary} from "../common/ParameterLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {CapLenderLibrary} from "../common/protocols/CapLenderLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {ResolvLibrary} from "../common/protocols/ResolvLibrary.sol";
import {SymbioticLibrary} from "../common/protocols/SymbioticLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library rstETHPlusLibrary {
    using ParameterLibrary for ParameterLibrary.Parameter[];

    function getSubvault0Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{any}()
            2. cowswap.swap(weth -> wsteth)
            3. rstETH.redeem(shares, subvault0, subvault0)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](8);
        uint256 iterator = 0;
        leaves[iterator++] = WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        leaves[iterator++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.RSTETH,
            0,
            abi.encodeCall(IERC4626.redeem, (0, subvault, subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IERC4626.redeem, (0, address(type(uint160).max), address(type(uint160).max)))
            )
        );

        assembly {
            mstore(leaves, iterator)
        }

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](8);
        uint256 iterator = 0;
        descriptions[iterator++] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        ParameterLibrary.Parameter[] memory innerParameters;
        innerParameters = ParameterLibrary.add2("shares", "any", "receiver", Strings.toHexString(subvault)).add(
            "owner", Strings.toHexString(subvault)
        );
        descriptions[iterator++] = JsonLibrary.toJson(
            string(abi.encodePacked("rstETH.redeem(any, subvault0, subvault0)")),
            ABILibrary.getABI(IERC4626.redeem.selector),
            ParameterLibrary.build(Strings.toHexString(curator), Strings.toHexString(Constants.RSTETH), "0"),
            innerParameters
        );

        assembly {
            mstore(descriptions, iterator)
        }
    }

    function getSubvault0SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);
        uint256 iterator = 0;
        calls.calls[iterator++] = WethLibrary.getWethDepositCalls(WethLibrary.Info(curator, Constants.WETH));
        iterator = ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            iterator
        );

        {
            address asset = Constants.RSTETH;
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, asset, 0, abi.encodeCall(IERC4626.redeem, (0, subvault, subvault)), true);
            tmp[i++] = Call(curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, subvault, subvault)), true);
            tmp[i++] =
                Call(address(0xdead), asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, subvault, subvault)), false);
            tmp[i++] =
                Call(curator, address(0xdead), 0, abi.encodeCall(IERC4626.redeem, (1 ether, subvault, subvault)), false);
            tmp[i++] =
                Call(curator, asset, 1 wei, abi.encodeCall(IERC4626.redeem, (1 ether, subvault, subvault)), false);
            tmp[i++] =
                Call(curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, address(0xdead), subvault)), false);
            tmp[i++] =
                Call(curator, asset, 0, abi.encodeCall(IERC4626.redeem, (1 ether, subvault, address(0xdead))), false);
            tmp[i++] = Call(curator, asset, 0, abi.encode(IERC4626.redeem.selector, 1 ether, subvault, subvault), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[iterator++] = tmp;
        }
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
                bitmaskVerifier,
                SymbioticLibrary.Info({
                    symbioticVault: capSymbioticVault,
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator
                })
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
                SymbioticLibrary.Info({
                    symbioticVault: capSymbioticVault,
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator
                })
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
            SymbioticLibrary.getSymbioticCalls(
                SymbioticLibrary.Info({
                    symbioticVault: capSymbioticVault,
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator
                })
            ),
            iterator
        );
    }
}
