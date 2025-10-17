// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";
import {IAavePoolV3} from "../common/interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";
import {Constants} from "./Constants.sol";

library AlphapingLibrary {
    /*
        subvault 0:
        eth, weth, usdc

        weth deposit
        weth withdrawal
        swaps [usdc, weth]

        allowed assets: usdc
        1. morpho erc4626
        2. bracket deposit
        3. cowswap (usdc, usdu)
        4. curve [usdc, usdu], gauge
        5.

        allowed assets: [weth]
        1. morpho erc4626
    */

    function getSubvault0Proofs(address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            allowed assets: usdc
            1. morpho deposit
            2. bracket deposit
            3. cowswap (usdc, usdu)
            4. curve usdc, usdu
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](4);

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions(address curator) internal view returns (string[] memory descriptions) {
        descriptions = new string[](4);
        descriptions[0] = WethLibrary.getWethDepositDescription(WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            1
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
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH))
                })
            ),
            1
        );
    }
}
