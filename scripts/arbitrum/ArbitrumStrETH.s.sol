// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../common/ArraysLibrary.sol";
import "../common/Permissions.sol";
import "./Constants.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";

import {ArbitrumStrETHLibrary} from "./ArbitrumStrETHLibrary.sol";

import {IL2GatewayRouter} from "../common/interfaces/IL2GatewayRouter.sol";

contract Deploy is Script, Test {
    address public immutable proxyAdminOwner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public immutable lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public immutable curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public immutable activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](50);
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

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

        (address verifier, SubvaultCalls memory calls_) = _createVerifier(address(vault));
        address subvault = vault.createSubvault(0, proxyAdminOwner, verifier);
        vault.renounceRole(Permissions.CREATE_SUBVAULT_ROLE, deployer);

        SubvaultCalls[] memory calls = new SubvaultCalls[](1);
        calls[0] = calls_;
        vm.stopBroadcast();

        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(),
            VaultDeployment({
                vault: vault,
                calls: calls,
                initParams: initParams,
                holders: _getExpectedHolders(),
                depositHook: address(0),
                redeemHook: address(0),
                assets: new address[](0),
                depositQueueAssets: new address[](0),
                redeemQueueAssets: new address[](0),
                subvaultVerifiers: ArraysLibrary.makeAddressArray(abi.encode(Subvault(payable(subvault)).verifier())),
                timelockControllers: new address[](0),
                timelockProposers: new address[](0),
                timelockExecutors: new address[](0)
            })
        );
        revert("ok");
    }

    function _getExpectedHolders() internal view returns (Vault.RoleHolder[] memory holders) {
        holders = new Vault.RoleHolder[](50);
        uint256 i = 0;

        // lazyVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.DEFAULT_ADMIN_ROLE, lazyVaultAdmin);

        // activeVaultAdmin roles:
        holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);

        // curator roles:
        holders[i++] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);

        assembly {
            mstore(holders, i)
        }
    }

    function _createVerifier(address vault) internal returns (address verifier, SubvaultCalls memory calls) {
        ArbitrumStrETHLibrary.Info memory info = ArbitrumStrETHLibrary.Info({
            curator: curator,
            ethereumAsset: Constants.WSTETH_ETHEREUM,
            ethereumSubvault: Constants.STRETH_ETHEREUM_SUBVAULT_0,
            l2GatewayRouter: Constants.L2_GATEWAY_ROUTER
        });

        string[] memory descriptions = ArbitrumStrETHLibrary.getArbitrumStrETHDescriptions(info);
        (bytes32 merkleRoot, IVerifier.VerificationPayload[] memory leaves) =
            ArbitrumStrETHLibrary.getArbitrumStrETHProofs(info);
        ProofLibrary.storeProofs("arbitrum:strETH:subvault0", merkleRoot, leaves, descriptions);
        calls = ArbitrumStrETHLibrary.getArbitrumStrETHCalls(info, leaves);

        verifier =
            Constants.protocolDeployment().verifierFactory.create(0, proxyAdminOwner, abi.encode(vault, merkleRoot));
    }
}
