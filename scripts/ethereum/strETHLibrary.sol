// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../common/interfaces/IAavePoolV3.sol";
import "../common/interfaces/ICowswapSettlement.sol";
import {IWETH as WETHInterface} from "../common/interfaces/IWETH.sol";
import {IWSTETH as WSTETHInterface} from "../common/interfaces/IWSTETH.sol";

import "../common/AcceptanceLibrary.sol";
import "../common/Permissions.sol";
import "../common/ProofLibrary.sol";

import "./Constants.sol";

library strETHLibrary {
    function getSubvault0Proofs(address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{value: <any>}();
            2. weth.approve(cowswapVaultRelayer, <any>);
            3. cowswapSettlement.setPreSignature(anyBytes(56), anyBool);
            4. cowswapSettlement.invalidateOrder(anyBytes(56)); 
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        uint256 i = 0;
        leaves = new IVerifier.VerificationPayload[](4);
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(WETHInterface.deposit, ()),
            ProofLibrary.makeBitmask(true, true, false, true, abi.encodeCall(WETHInterface.deposit, ()))
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
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
        descriptions = new string[](4);
        uint256 i = 0;
        descriptions[i++] = "WETH.deposit{value: any}()";
        descriptions[i++] = "WETH.approve(CowswapVaultRelayer, any)";
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

        // 2. weth.approve(cowswapVaultRelayer, <any>);
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
            calls.calls[1] = tmp;
        }

        // 3. cowswapSettlement.setPreSignature(anyBytes(56), anyBool);
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

            calls.calls[2] = tmp;
        }

        // 4. cowswapSettlement.invalidateOrder(anyBytes);
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

            calls.calls[3] = tmp;
        }
    }

    function getSubvault1Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.approve(cowswap, anyInt)
            2. wsteth.approve(cowswap, anyInt)
            3. cowswap.setPreSignature(anyBytes(56), anyBool)
            4. cowswap.invalidateOrder(anyBytes(56))

            5. wsteth.approve(AaveV3Prime, anyInt)
            6. weth.approve(AaveV3Prime, anyInt)
          
            7. AaveV3Prime.setEMode(category=1)
            8. AaveV3Prime.borrow(weth, anyInt, 2, anyInt, subvault1)
            9. AaveV3Prime.repay(weth, anyInt, 2, subvault1)
            10. AaveV3Prime.supply(wsteth, anyInt, subvault1, anyInt)
            11. AaveV3Prime.withdraw(wsteth, anyInt, subvault1)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        uint256 i = 0;
        leaves = new IVerifier.VerificationPayload[](11);
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.setPreSignature, (new bytes(56), false))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.COWSWAP_SETTLEMENT,
            0,
            abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56))),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(ICowswapSettlement.invalidateOrder, (new bytes(56)))
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );
        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.WSTETH,
            0,
            abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 0)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IERC20.approve, (address(type(uint160).max), 0))
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.AAVE_PRIME,
            0,
            abi.encodeCall(IAavePoolV3.setUserEMode, (1)),
            ProofLibrary.makeBitmask(
                true, true, true, true, abi.encodeCall(IAavePoolV3.setUserEMode, (type(uint8).max))
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.AAVE_PRIME,
            0,
            abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 0, 2, 0, subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IAavePoolV3.borrow,
                    (address(type(uint160).max), 0, type(uint256).max, 0, address(type(uint160).max))
                )
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.AAVE_PRIME,
            0,
            abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 0, 2, subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(
                    IAavePoolV3.repay, (address(type(uint160).max), 0, type(uint256).max, address(type(uint160).max))
                )
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.AAVE_PRIME,
            0,
            abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 0, subvault, 0)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IAavePoolV3.supply, (address(type(uint160).max), 0, address(type(uint160).max), 0))
            )
        );

        leaves[i++] = ProofLibrary.makeVerificationPayload(
            bitmaskVerifier,
            curator,
            Constants.AAVE_PRIME,
            0,
            abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 0, subvault)),
            ProofLibrary.makeBitmask(
                true,
                true,
                true,
                true,
                abi.encodeCall(IAavePoolV3.withdraw, (address(type(uint160).max), 0, address(type(uint160).max)))
            )
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions() internal pure returns (string[] memory descriptions) {
        descriptions = new string[](11);

        uint256 i = 0;
        descriptions[i++] = "WETH.approve(CowswapVaultRelayer, any)";
        descriptions[i++] = "WSTETH.approve(CowswapVaultRelayer, any)";
        descriptions[i++] = "CowswapSettlement.setPreSignature(anyBytes(56), anyBool)";
        descriptions[i++] = "CowswapSettlement.invalidateOrder(anyBytes(56))";

        descriptions[i++] = "WETH.approve(AavePoolV3(Prime), any)";
        descriptions[i++] = "WSTETH.approve(AavePoolV3(Prime), any)";

        descriptions[i++] = "AavePoolV3(Prime).setUserEMode(categoryId=1)";
        descriptions[i++] = "AavePoolV3(Prime).borrow(WETH, any, interestRateMode=2, any, subvault1)";
        descriptions[i++] = "AavePoolV3(Prime).repay(WETH, any, interestRateMode=2, subvault1)";
        descriptions[i++] = "AavePoolV3(Prime).supply(WSTETH, 0, subvault1, 0)";
        descriptions[i++] = "AavePoolV3(Prime).withdraw(WSTETH, 0, subvault1)";
    }

    function getSubvault1SubvaultCalls(
        ProtocolDeployment memory $,
        address curator,
        address subvault,
        IVerifier.VerificationPayload[] memory leaves
    ) internal pure returns (SubvaultCalls memory calls) {
        /*
            1. weth.approve(cowswap, anyInt)
            2. wsteth.approve(cowswap, anyInt)
            3. cowswap.setPreSignature(anyBytes(56), anyBool)
            4. cowswap.invalidateOrder(anyBytes(56))

            5. weth.approve(AaveV3Prime, anyInt)
            6. wsteth.approve(AaveV3Prime, anyInt)
          
            7. AaveV3Prime.setEMode(category=1)
            8. AaveV3Prime.borrow(weth, anyInt, 2, anyInt, subvault1)
            9. AaveV3Prime.repay(weth, anyInt, 2, subvault1)
            10. AaveV3Prime.supply(wsteth, anyInt, subvault1, anyInt)
            11. AaveV3Prime.withdraw(wsteth, anyInt, subvault1)
        */
        calls.payloads = leaves;
        calls.calls = new Call[][](leaves.length);

        // 1. weth.approve(cowswap, anyInt)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[i++] = Call(
                curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)), true
            );
            tmp[i++] = Call(
                curator,
                $.weth,
                1 wei,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.deployer, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)), false
            );
            tmp[i++] = Call(
                curator,
                $.deployer,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)),
                false
            );
            tmp[i++] =
                Call(curator, $.weth, 0, abi.encodePacked(Constants.COWSWAP_VAULT_RELAYER, uint256(1 ether)), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[0] = tmp;
        }

        // 2. wsteth.approve(cowswap, anyInt)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] =
                Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 0)), true);
            tmp[i++] = Call(
                curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)), true
            );
            tmp[i++] = Call(
                curator,
                $.wsteth,
                1 wei,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)),
                false
            );
            tmp[i++] = Call(
                $.deployer,
                $.wsteth,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)),
                false
            );
            tmp[i++] = Call(
                curator,
                $.deployer,
                0,
                abi.encodeCall(IERC20.approve, (Constants.COWSWAP_VAULT_RELAYER, 1 ether)),
                false
            );
            tmp[i++] =
                Call(curator, $.wsteth, 0, abi.encodePacked(Constants.COWSWAP_VAULT_RELAYER, uint256(1 ether)), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[1] = tmp;
        }

        // 3. cowswap.setPreSignature(anyBytes(56), anyBool)
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

            calls.calls[2] = tmp;
        }

        // 4. cowswap.invalidateOrder(anyBytes(56))
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

            calls.calls[3] = tmp;
        }

        // 5. weth.approve(AaveV3Prime, anyInt)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 0)), true);
            tmp[i++] = Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), true);
            tmp[i++] =
                Call(curator, $.weth, 1 wei, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] =
                Call($.deployer, $.weth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] =
                Call(curator, $.deployer, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] =
                Call(curator, $.deployer, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] = Call(curator, $.weth, 0, abi.encodeCall(IERC20.approve, ($.deployer, 1 ether)), false);
            tmp[i++] = Call(curator, $.weth, 0, abi.encodePacked(Constants.AAVE_PRIME, uint256(1 ether)), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[4] = tmp;
        }

        // 6. wsteth.approve(AaveV3Prime, anyInt)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 0)), true);
            tmp[i++] = Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), true);
            tmp[i++] =
                Call(curator, $.wsteth, 1 wei, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] =
                Call($.deployer, $.wsteth, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] =
                Call(curator, $.deployer, 0, abi.encodeCall(IERC20.approve, (Constants.AAVE_PRIME, 1 ether)), false);
            tmp[i++] = Call(curator, $.wsteth, 0, abi.encodeCall(IERC20.approve, ($.deployer, 1 ether)), false);
            tmp[i++] = Call(curator, $.wsteth, 0, abi.encodePacked(Constants.AAVE_PRIME, uint256(1 ether)), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[5] = tmp;
        }

        // 7. AaveV3Prime.setEMode(category=1)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encodeCall(IAavePoolV3.setUserEMode, (1)), true);
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encodeCall(IAavePoolV3.setUserEMode, (0)), false);
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 1 wei, abi.encodeCall(IAavePoolV3.setUserEMode, (1)), false);
            tmp[i++] = Call(curator, $.deployer, 0, abi.encodeCall(IAavePoolV3.setUserEMode, (1)), false);
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encode(uint256(1)), false);
            tmp[i++] = Call($.deployer, Constants.AAVE_PRIME, 0, abi.encodeCall(IAavePoolV3.setUserEMode, (1)), false);
            tmp[i++] =
                Call(curator, Constants.AAVE_PRIME, 0, abi.encodePacked(IAavePoolV3.borrow.selector, uint256(1)), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[6] = tmp;
        }

        // 8. AaveV3Prime.borrow(weth, anyInt, 2, anyInt, subvault1)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 0, 2, 0, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 2, 1, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 1, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                1 wei,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 2, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                $.deployer,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 2, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                $.deployer,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 2, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, ($.deployer, 1 ether, 2, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.borrow, (Constants.WETH, 1 ether, 2, 1, $.deployer)),
                false
            );
            tmp[i++] =
                Call(curator, Constants.AAVE_PRIME, 0, abi.encode(Constants.WETH, 1 ether, 2, 1, subvault), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[7] = tmp;
        }

        // 9. AaveV3Prime.repay(weth, anyInt, 2, subvault1)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 0, 2, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 2, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 1, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                1 wei,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 2, subvault)),
                false
            );
            tmp[i++] = Call(
                curator, $.deployer, 0, abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 2, subvault)), false
            );
            tmp[i++] = Call(
                $.deployer,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 2, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, ($.deployer, 1 ether, 2, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.repay, (Constants.WETH, 1 ether, 2, $.deployer)),
                false
            );
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encode(Constants.WETH, 1 ether, 2, subvault), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[8] = tmp;
        }

        // 10. AaveV3Prime.supply(wsteth, anyInt, subvault1, anyInt)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 0, subvault, 0)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 1 ether, subvault, 1)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                1 wei,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 1 ether, subvault, 1)),
                false
            );
            tmp[i++] = Call(
                curator,
                $.deployer,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 1 ether, subvault, 1)),
                false
            );
            tmp[i++] = Call(
                $.deployer,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 1 ether, subvault, 1)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WETH, 1 ether, subvault, 1)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, ($.deployer, 1 ether, subvault, 1)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.supply, (Constants.WSTETH, 1 ether, $.deployer, 1)),
                false
            );
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encode(Constants.WSTETH, 1 ether, subvault, 1), false);

            assembly {
                mstore(tmp, i)
            }
            calls.calls[9] = tmp;
        }

        // 11. AaveV3Prime.withdraw(wsteth, anyInt, subvault1)
        {
            Call[] memory tmp = new Call[](16);
            uint256 i = 0;
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 0, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 1 ether, subvault)),
                true
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                1 wei,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 1 ether, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                $.deployer,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 1 ether, subvault)),
                false
            );
            tmp[i++] = Call(
                $.deployer,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 1 ether, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, ($.deployer, 1 ether, subvault)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WSTETH, 1 ether, $.deployer)),
                false
            );
            tmp[i++] = Call(
                curator,
                Constants.AAVE_PRIME,
                0,
                abi.encodeCall(IAavePoolV3.withdraw, (Constants.WETH, 1 ether, subvault)),
                false
            );
            tmp[i++] = Call(curator, Constants.AAVE_PRIME, 0, abi.encode(Constants.WSTETH, 1 ether, subvault), false);
            assembly {
                mstore(tmp, i)
            }
            calls.calls[10] = tmp;
        }
    }
}
