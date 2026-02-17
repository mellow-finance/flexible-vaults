// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/ArraysLibrary.sol";
import "../common/Permissions.sol";
import "./Constants.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {PlasmaStrETHLibrary} from "./PlasmaStrETHLibrary.sol";

import {IL2GatewayRouter} from "../common/interfaces/IL2GatewayRouter.sol";

import "../common/interfaces/ILayerZeroOFT.sol";
import "../common/libraries/CCIPClient.sol";

contract Deploy is Script, Test {
    address public immutable proxyAdminOwner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public immutable lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public immutable curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public immutable activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;

    uint256 public constant DEFAULT_MULTIPLIER = 0.995e8;

    function run() external {
        // {
        //     IVerifier.VerificationPayload memory payload;
        //     payload.verificationType = IVerifier.VerificationType.CUSTOM_VERIFIER;
        //     payload.verificationData =
        //         hex"0000000000000000000000000000000263fb29c3d6b0c5837883519ef05ea20a71ae8c58d3e73743db9db91bef073281144659d18c2ed41772f38a762db7530400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000224ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000ffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        //     payload.proof = ArraysLibrary.makeBytes32Array(
        //         abi.encode(
        //             0xae80c0dbf9042d1c228dbbcf5a7f738a3071b93728daf1164174a3844cb373e9,
        //             0x6b1eb7bc70162850439af82e02bbe01b4dc93078e63354beb0238f1c82ba2172,
        //             0xa46f118e4139cc3595e09dccbab4127486f2305308ff82622809944dfeacdfaa,
        //             0x491060c5134ccf2a04b00bf75b61b01e60609571836212797171727f1d51d9e6
        //         )
        //     );

        //     ILayerZeroOFT oft = ILayerZeroOFT(0x2a52B289bA68bBd02676640aA9F605700c9e5699);
        //     uint256 amount = 10e6 ether;
        //     address subvault = 0xbbF9400C09B0F649F3156989F1CCb9c016f943bb;
        //     ILayerZeroOFT.SendParam memory sendParams = ILayerZeroOFT.SendParam({
        //         dstEid: 30101,
        //         to: 0x000000000000000000000000ecf3bde9f50f71ede67e05050123b64b519df55c,
        //         amountLD: amount,
        //         minAmountLD: amount,
        //         extraOptions: "",
        //         composeMsg: "",
        //         oftCmd: ""
        //     });
        //     uint256 fees = oft.quoteSend(sendParams, false);
        //     fees *= 2;
        //     console2.logBytes(
        //         abi.encodeCall(
        //             ICallModule.call,
        //             (
        //                 address(oft),
        //                 fees,
        //                 abi.encodeCall(
        //                     oft.send,
        //                     (
        //                         sendParams,
        //                         ILayerZeroOFT.MessagingFee(fees, 0),
        //                         0xbbF9400C09B0F649F3156989F1CCb9c016f943bb
        //                     )
        //                 ),
        //                 payload
        //             )
        //         )
        //     );
        //     return;
        // }

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        TimelockController timelockController = new TimelockController(
            0,
            ArraysLibrary.makeAddressArray(abi.encode(deployer, lazyVaultAdmin)),
            ArraysLibrary.makeAddressArray(abi.encode(curator, activeVaultAdmin)),
            lazyVaultAdmin
        );

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](50);
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

            // timelock roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

            // curator roles:
            holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

            // deployer roles:
            holders[i++] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);

            assembly {
                mstore(holders, i)
            }
        }

        ProtocolDeployment memory deployment = Constants.protocolDeployment();
        Vault vault;
        VaultConfigurator.InitParams memory initParams;
        {
            IOracle.SecurityParams memory securityParams = IOracle.SecurityParams({
                maxAbsoluteDeviation: 1,
                suspiciousAbsoluteDeviation: 1,
                maxRelativeDeviationD18: 1,
                suspiciousRelativeDeviationD18: 1,
                timeout: type(uint32).max,
                depositInterval: type(uint32).max,
                redeemInterval: type(uint32).max
            });
            initParams = VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: proxyAdminOwner,
                vaultAdmin: lazyVaultAdmin,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "Mellow stRATEGY", "strETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(lazyVaultAdmin, lazyVaultAdmin, 0, 0, 0, 0),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(0),
                oracleVersion: 0,
                oracleParams: abi.encode(securityParams, new address[](0)),
                defaultDepositHook: address(0),
                defaultRedeemHook: address(0),
                queueLimit: 0,
                roleHolders: holders
            });
            (,,,, address vault_) = deployment.vaultConfigurator.create(initParams);
            vault = Vault(payable(vault_));
        }

        address verifier =
            Constants.protocolDeployment().verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, bytes32(0)));
        address subvault = vault.createSubvault(0, proxyAdminOwner, verifier);
        (bytes32 merkleRoot, SubvaultCalls memory calls_) =
            _createSubvault0Verifier(address(vault), _deployResolvPlasmaLeverage(subvault));
        IVerifier(verifier).setMerkleRoot(merkleRoot);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);

        SubvaultCalls[] memory calls = new SubvaultCalls[](1);
        calls[0] = calls_;

        timelockController.schedule(
            verifier, 0, abi.encodeCall(IVerifier.setMerkleRoot, (bytes32(0))), bytes32(0), bytes32(0), 0
        );

        timelockController.renounceRole(timelockController.PROPOSER_ROLE(), deployer);
        timelockController.renounceRole(timelockController.CANCELLER_ROLE(), deployer);

        console.log("Vault: %s", address(vault));
        console.log("Subvault: %s", address(subvault));
        console.log("Verifier: %s", address(verifier));
        console.log("TimelockController: %s", address(timelockController));

        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(timelockController),
                depositHook: address(0),
                redeemHook: address(0),
                assets: new address[](0),
                depositQueueAssets: new address[](0),
                redeemQueueAssets: new address[](0),
                subvaultVerifiers: ArraysLibrary.makeAddressArray(abi.encode(Subvault(payable(subvault)).verifier())),
                timelockControllers: ArraysLibrary.makeAddressArray(abi.encode(timelockController)),
                timelockProposers: ArraysLibrary.makeAddressArray(abi.encode(lazyVaultAdmin)),
                timelockExecutors: ArraysLibrary.makeAddressArray(abi.encode(curator, activeVaultAdmin))
            })
        );
        // revert("ok");
    }

    function _getExpectedHolders(TimelockController timelockController)
        internal
        view
        returns (Vault.RoleHolder[] memory holders)
    {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // timelock roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }

    function _createSubvault0Verifier(address subvault, address swapModule)
        internal
        returns (bytes32 merkleRoot, SubvaultCalls memory calls)
    {
        PlasmaStrETHLibrary.Info memory info = PlasmaStrETHLibrary.Info({
            curator: curator,
            subvault: subvault,
            subvaultName: "subvault0",
            asset: Constants.WSTETH,
            ethereumSubvault: Constants.STRETH_ETHEREUM_SUBVAULT_0,
            ccipRouter: Constants.CCIP_PLASMA_ROUTER,
            ccipEthereumSelector: Constants.CCIP_ETHEREUM_CHAIN_SELECTOR,
            swapModule: swapModule
        });
        string[] memory descriptions = PlasmaStrETHLibrary.getSubvault0Descriptions(info);
        IVerifier.VerificationPayload[] memory leaves;
        (merkleRoot, leaves) = PlasmaStrETHLibrary.getSubvault0Proofs(info);
        ProofLibrary.storeProofs("plasma:strETH:subvault0", merkleRoot, leaves, descriptions);
        calls = PlasmaStrETHLibrary.getSubvault0SubvaultCalls(info, leaves);
    }

    function _deployResolvPlasmaLeverage(address subvault) internal returns (address) {
        IFactory swapModuleFactory = Constants.protocolDeployment().swapModuleFactory;
        address[] memory actors = ArraysLibrary.makeAddressArray(
            abi.encode(curator, Constants.WXPL, Constants.USDT0, Constants.KYBERSWAP_ROUTER)
        );
        bytes32[] memory permissions = ArraysLibrary.makeBytes32Array(
            abi.encode(
                Permissions.SWAP_MODULE_CALLER_ROLE,
                Permissions.SWAP_MODULE_TOKEN_IN_ROLE,
                Permissions.SWAP_MODULE_TOKEN_OUT_ROLE,
                Permissions.SWAP_MODULE_ROUTER_ROLE
            )
        );
        return swapModuleFactory.create(
            0,
            proxyAdminOwner,
            abi.encode(lazyVaultAdmin, subvault, Constants.AAVE_V3_ORACLE, DEFAULT_MULTIPLIER, actors, permissions)
        );
    }
}
