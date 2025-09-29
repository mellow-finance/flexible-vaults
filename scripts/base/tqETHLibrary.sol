// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "../common/ArraysLibrary.sol";
import "../common/CowSwapLibrary.sol";

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
        uint256 i = 0;
        leaves = new IVerifier.VerificationPayload[](6);
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(WETHInterface.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(WETHInterface.deposit, ()))
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(WETHInterface.withdraw, (0)),
            ProofLibrary.makeBitmask(true, true, true, true, abi.encodeCall(WETHInterface.withdraw, (0)))
        );

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
        uint256 i = 0;
        descriptions[i++] = "WETH.deposit{value: any}()";
        descriptions[i++] = "WETH.withdraw(any)";

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

        // 1. weth.deposit{value: <any>}();
        {
            Call[] memory tmp = new Call[](5);
            tmp[0] = Call(curator, $.weth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), true);
            tmp[1] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.deposit, ()), true);
            tmp[2] = Call($.deployer, $.weth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), false);
            tmp[3] = Call(curator, $.wsteth, 1 ether, abi.encodeCall(WETHInterface.deposit, ()), false);
            tmp[4] = Call(curator, $.weth, 1 ether, abi.encodePacked(WETHInterface.deposit.selector, uint256(0)), false);
            calls.calls[0] = tmp;
        }

        // 2. weth.withdraw(<any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), true);
            tmp[1] = Call(curator, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (type(uint256).max)), true);
            tmp[2] = Call($.deployer, $.weth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            tmp[3] = Call(curator, $.wsteth, 0, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            tmp[4] = Call(curator, $.weth, 0, abi.encodePacked(WETHInterface.withdraw.selector), false);
            tmp[5] = Call(curator, $.weth, 1 ether, abi.encodeCall(WETHInterface.withdraw, (0)), false);
            calls.calls[1] = tmp;
        }

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
