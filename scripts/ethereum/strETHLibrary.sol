// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IAavePoolV3} from "../common/interfaces/IAavePoolV3.sol";
import {ICowswapSettlement} from "../common/interfaces/ICowswapSettlement.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Permissions} from "../common/Permissions.sol";
import {ProofLibrary} from "../common/ProofLibrary.sol";

import {AaveLibrary} from "../common/protocols/AaveLibrary.sol";
import {CowSwapLibrary} from "../common/protocols/CowSwapLibrary.sol";
import {WethLibrary} from "../common/protocols/WethLibrary.sol";

import {BitmaskVerifier, Call, IVerifier, ProtocolDeployment, SubvaultCalls} from "../common/interfaces/Imports.sol";
import "./Constants.sol";

library strETHLibrary {
    function getSubvault0Proofs(address curator)
        internal
        pure
        returns (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1. weth.deposit{value: <any>}();
            2-4. cowswap (assets=[weth])
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](4);
        leaves[0] = WethLibrary.getWethDepositProof(bitmaskVerifier, WethLibrary.Info(curator, Constants.WETH));
        ArraysLibrary.insert(
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
            1
        );
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

    function getSubvault1Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-4. cowswap (assets=[weth, wsteth])
            5-11. aave (collaterals=[wsteth], loans=[weth], categoryId=1)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        leaves = new IVerifier.VerificationPayload[](11);
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    curator: curator,
                    assets: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH, Constants.WSTETH))
                })
            ),
            0
        );
        ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault1Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        descriptions = new string[](11);
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
            0
        );
        ArraysLibrary.insert(
            descriptions,
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
    }

    function getSubvault1SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
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
            4
        );
        ArraysLibrary.insert(
            calls.calls,
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault1",
                    curator: curator,
                    aaveInstance: Constants.AAVE_PRIME,
                    aaveInstanceName: "Prime",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.WETH)),
                    categoryId: 1
                })
            ),
            4
        );
    }

    function getSubvault2Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-7. aave (collaterals=[wsteth], loans=[usdc, usdt, usds], categoryId=0)
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;
        return ProofLibrary.generateMerkleProofs(
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault2",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 0
                })
            )
        );
    }

    function getSubvault2Descriptions(address curator, address subvault) internal view returns (string[] memory) {
        return AaveLibrary.getAaveDescriptions(
            AaveLibrary.Info({
                subvault: subvault,
                subvaultName: "subvault2",
                curator: curator,
                aaveInstance: Constants.AAVE_CORE,
                aaveInstanceName: "Core",
                collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                categoryId: 0
            })
        );
    }

    function getSubvault2SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        calls.payloads = leaves;
        calls.calls = AaveLibrary.getAaveCalls(
            AaveLibrary.Info({
                subvault: subvault,
                subvaultName: "subvault2",
                curator: curator,
                aaveInstance: Constants.AAVE_CORE,
                aaveInstanceName: "Core",
                collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.WSTETH)),
                loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                categoryId: 0
            })
        );
    }

    function getSubvault3Proofs(address curator, address subvault)
        internal
        pure
        returns (bytes32 merkleProof, IVerifier.VerificationPayload[] memory leaves)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        BitmaskVerifier bitmaskVerifier = Constants.protocolDeployment().bitmaskVerifier;

        leaves = new IVerifier.VerificationPayload[](23);
        ArraysLibrary.insert(
            leaves,
            AaveLibrary.getAaveProofs(
                bitmaskVerifier,
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            leaves,
            CowSwapLibrary.getCowSwapProofs(
                bitmaskVerifier,
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );

        return ProofLibrary.generateMerkleProofs(leaves);
    }

    function getSubvault3Descriptions(address curator, address subvault)
        internal
        view
        returns (string[] memory descriptions)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        descriptions = new string[](23);
        ArraysLibrary.insert(
            descriptions,
            AaveLibrary.getAaveDescriptions(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            descriptions,
            CowSwapLibrary.getCowSwapDescriptions(
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );
    }

    function getSubvault3SubvaultCalls(address curator, address subvault, IVerifier.VerificationPayload[] memory leaves)
        internal
        pure
        returns (SubvaultCalls memory calls)
    {
        /*
            1-16. aave (collaterals=[usde, susde], loans=[usdc, usdt, usds], categoryId=2)
            17-23. cowswap(assets=[usde, susde, usdc, usdt, usds])
        */
        calls.payloads = leaves;
        calls.calls = new Call[][](23);
        ArraysLibrary.insert(
            calls.calls,
            AaveLibrary.getAaveCalls(
                AaveLibrary.Info({
                    subvault: subvault,
                    subvaultName: "subvault3",
                    curator: curator,
                    aaveInstance: Constants.AAVE_CORE,
                    aaveInstanceName: "Core",
                    collaterals: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDE, Constants.SUSDE)),
                    loans: ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDT, Constants.USDS)),
                    categoryId: 2
                })
            ),
            0
        );
        ArraysLibrary.insert(
            calls.calls,
            CowSwapLibrary.getCowSwapCalls(
                CowSwapLibrary.Info({
                    curator: curator,
                    cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                    cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                    assets: ArraysLibrary.makeAddressArray(
                        abi.encode(Constants.USDE, Constants.SUSDE, Constants.USDC, Constants.USDT, Constants.USDS)
                    )
                })
            ),
            16
        );
    }
}
