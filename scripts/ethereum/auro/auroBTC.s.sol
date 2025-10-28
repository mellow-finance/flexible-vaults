// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../../../src/vaults/VaultConfigurator.sol";

import "../../common/ArraysLibrary.sol";
import "../../common/Permissions.sol";

import "../Constants.sol";
import "./AuroBTCDeployBase.sol";
import "./AuroBTC_AcceptReportBase.sol";

contract Deploy is AuroBTCDeployBase {
    function getStorageKey() internal pure override returns (string memory) {
        return "ethereum:auroBTC:subvault0";
    }

    function getInitParams(address deployer, TimelockController timelockController, ProtocolDeployment memory $)
        internal
        pure
        override
        returns (VaultConfigurator.InitParams memory initParams)
    {
        address[] memory assets_ = ArraysLibrary.makeAddressArray(abi.encode(WBTC));

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](23);
        holders[0] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, activeVaultAdmin);
        holders[1] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, activeVaultAdmin);
        holders[2] = Vault.RoleHolder(Permissions.ALLOW_CALL_ROLE, activeVaultAdmin);
        holders[3] = Vault.RoleHolder(Permissions.DISALLOW_CALL_ROLE, activeVaultAdmin);
        holders[4] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[5] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, activeVaultAdmin);
        holders[6] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, activeVaultAdmin);
        holders[7] = Vault.RoleHolder(Permissions.MODIFY_VAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[8] = Vault.RoleHolder(Permissions.MODIFY_SUBVAULT_BALANCE_ROLE, activeVaultAdmin);
        holders[9] = Vault.RoleHolder(Permissions.SET_FLAGS_ROLE, address(timelockController));
        holders[10] = Vault.RoleHolder(Permissions.SET_MERKLE_ROOT_ROLE, address(timelockController));
        holders[11] = Vault.RoleHolder(Permissions.SET_QUEUE_STATUS_ROLE, address(timelockController));
        holders[12] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, oracleUpdater);
        holders[13] = Vault.RoleHolder(Permissions.CALLER_ROLE, curator);
        holders[14] = Vault.RoleHolder(Permissions.PULL_LIQUIDITY_ROLE, curator);
        holders[15] = Vault.RoleHolder(Permissions.PUSH_LIQUIDITY_ROLE, curator);
        holders[16] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
        holders[17] = Vault.RoleHolder(Permissions.CREATE_SUBVAULT_ROLE, deployer);
        holders[18] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        holders[19] = Vault.RoleHolder(Permissions.ALLOW_SUBVAULT_ASSETS_ROLE, deployer);
        holders[20] = Vault.RoleHolder(Permissions.SET_SUBVAULT_LIMIT_ROLE, deployer);
        holders[21] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, deployer);
        holders[22] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, deployer);

        initParams = VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: lazyVaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0), "Auro BTC predeposit", "auroBTC.pre"),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(deployer, lazyVaultAdmin, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(type(int256).max / 2),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.005 ether,
                    suspiciousAbsoluteDeviation: 0.001 ether,
                    maxRelativeDeviationD18: 0.005 ether,
                    suspiciousRelativeDeviationD18: 0.001 ether,
                    timeout: 20 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 2 days
                }),
                assets_
            ),
            defaultDepositHook: address($.redirectingDepositHook),
            defaultRedeemHook: address($.basicRedeemHook),
            queueLimit: 6,
            roleHolders: holders
        });
    }
}

contract AcceptReport is AuroBTC_AcceptReportBase {}
