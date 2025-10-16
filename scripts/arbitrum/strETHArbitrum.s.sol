// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "../common/Permissions.sol";
import "./Constants.sol";

contract Deploy is Script {
    address public immutable proxyAdminOwner = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address public immutable lazyVaultAdmin = 0xAbE20D266Ae54b9Ae30492dEa6B6407bF18fEeb5;
    address public immutable curator = 0x5Dbf9287787A5825beCb0321A276C9c92d570a75;
    address public immutable activeVaultAdmin = 0xeb1CaFBcC8923eCbc243ff251C385C201A6c734a;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](50);
        {
            uint256 i = 0;

            // activeVaultAdmin roles:
            holders[i++] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
            holders[i++] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);

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
            VaultConfigurator.InitParams memory initParams = VaultConfigurator.InitParams({
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
            (,,,, address vault_) = deployment.vaultConfigurator.create();
            vault = Vault(payable(vault_));
        }

        // bridge all liquidity back into subvault N (?)
        vault.createSubvault(0, proxyAdminOwner, _createVerifier());
    }

    function _createVerifier() internal returns (address) {
        address ethereumSubvault0 = 0x90c983DC732e65DB6177638f0125914787b8Cb78;

        /*
            Allowed calls:
            1. wsteth.approve(bridgeContract, any)
            2. bridge.doBridgingStuff(...)
        */
    }
}
