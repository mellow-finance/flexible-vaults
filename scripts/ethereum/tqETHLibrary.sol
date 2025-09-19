// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

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
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            $.bitmaskVerifier,
            curator,
            Constants.COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56)))
            )
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault0Descriptions() internal pure returns (string[] memory descriptions) {
        descriptions = new string[](6);
        uint256 i = 0;
        descriptions[i++] = "WETH.deposit{value: any}()";
        descriptions[i++] = "WETH.withdraw(any)";
        descriptions[i++] = "WETH.approve(CowswapVaultRelayer, any)";
        descriptions[i++] = "WstETH.approve(CowswapVaultRelayer, any)";
        descriptions[i++] = "CowswapSettlement.setPreSignature(anyBytes(56), anyBool)";
        descriptions[i++] = "CowswapSettlement.invalidateOrder(anyBytes(56))";
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

        // 3. weth.approve(cowswapVaultRelayer, <any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] =
                Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[1] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                true
            );
            tmp[2] = Call(
                $.deployer,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[3] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[4] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.transfer, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[5] = Call(
                curator,
                $.weth,
                1 ether,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            calls.calls[2] = tmp;
        }

        //  4. wsteth.approve(cowswapVaultRelayer, <any>);
        {
            Call[] memory tmp = new Call[](6);
            tmp[0] =
                Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[1] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                true
            );
            tmp[2] = Call(
                $.deployer,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[3] = Call(
                curator,
                $.weth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[4] = Call(
                curator,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.transfer, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            tmp[5] = Call(
                curator,
                $.wsteth,
                1 ether,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, type(uint256).max)),
                false
            );
            calls.calls[3] = tmp;
        }

        // 5. cowswapSettlement.setPreSignature(coswapOrderUid(owner=address(0)), anyBool);
        {
            Call[] memory tmp = new Call[](7);
            tmp[0] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                true
            );
            tmp[1] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                true
            );
            tmp[2] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(120), true)),
                false
            );

            tmp[3] = Call(
                curator, $.weth, 0, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)), false
            );

            tmp[4] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                1 wei,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), true)),
                false
            );
            tmp[5] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodePacked(ICowswapSettlement.setPreSignature.selector, new bytes(56)),
                false
            );
            tmp[6] = Call(
                $.deployer,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
                false
            );

            calls.calls[4] = tmp;
        }

        // 6. cowswapSettlement.invalidateOrder(anyBytes);
        {
            Call[] memory tmp = new Call[](8);
            tmp[0] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                true
            );
            bytes memory temp = new bytes(56);
            temp[0] = bytes1(uint8(1));
            tmp[1] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );
            tmp[2] = Call(
                address(0),
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            tmp[3] = Call(
                $.deployer,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            tmp[4] =
                Call(curator, $.weth, 0, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))), false);
            tmp[5] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                1 wei,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
                false
            );
            temp[25] = bytes1(uint8(1));
            tmp[6] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );
            temp[55] = bytes1(uint8(1));
            tmp[7] = Call(
                curator,
                Constants.COWSWAP_SETTLEMENT,
                0,
                abi.encodeCall(ICowswapSettlement.invalidateOrder, (temp)),
                true
            );

            calls.calls[5] = tmp;
        }
    }
}
