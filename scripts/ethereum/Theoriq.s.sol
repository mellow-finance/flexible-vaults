// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "./Permissions.sol";
import "./test/DummyReporterTheoriq.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        VaultConfigurator vaultConfigurator = VaultConfigurator(0x000000028be48f9E62E13403480B60C4822C5aa5);
        DummyReporterTheoriq dummyReporter = new DummyReporterTheoriq();

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](4);
        holders[0] = Vault.RoleHolder(Permissions.CREATE_QUEUE_ROLE, deployer);
        holders[1] = Vault.RoleHolder(Permissions.SET_VAULT_LIMIT_ROLE, deployer);
        holders[2] = Vault.RoleHolder(Permissions.SUBMIT_REPORTS_ROLE, address(dummyReporter));
        holders[3] = Vault.RoleHolder(Permissions.ACCEPT_REPORT_ROLE, address(dummyReporter));

        address[] memory assets_ = new address[](1);
        assets_[0] = TransferLibrary.ETH;

        (,,,, address vault_) = vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: deployer,
                vaultAdmin: deployer,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "[pre-prod]Theoriq AlphaVault ETH", "[pre-prod]tqETH"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, deployer, uint24(0), uint24(0), uint24(0), uint24(0)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(20000 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(
                    IOracle.SecurityParams({
                        maxAbsoluteDeviation: 0.00001 ether,
                        suspiciousAbsoluteDeviation: 0.00001 ether,
                        maxRelativeDeviationD18: 0.00001 ether,
                        suspiciousRelativeDeviationD18: 0.00001 ether,
                        timeout: 10 minutes,
                        depositInterval: 1 minutes,
                        redeemInterval: 1 minutes
                    }),
                    assets_
                ),
                defaultDepositHook: address(0),
                defaultRedeemHook: address(0),
                queueLimit: 2,
                roleHolders: holders
            })
        );
        Vault vault = Vault(payable(vault_));

        vault.createQueue(0, true, deployer, TransferLibrary.ETH, new bytes(0));
        vault.createQueue(0, false, deployer, TransferLibrary.ETH, new bytes(0));
        vault.feeManager().setBaseAsset(vault_, TransferLibrary.ETH);

        dummyReporter.push(vault);

        IDepositQueue queue = IDepositQueue(vault.queueAt(TransferLibrary.ETH, 0));
        queue.deposit{value: 1 gwei}(1 gwei, address(0), new bytes32[](0));

        console2.log("Vault %s", address(vault));
        console2.log("Oracle %s", address(vault.oracle()));
        console2.log("ShareManager %s", address(vault.shareManager()));
        console2.log("RiskManager %s", address(vault.riskManager()));
        console2.log("FeeManager %s", address(vault.feeManager()));
        console2.log("DepositQueue (ETH) %s", address(vault.queueAt(TransferLibrary.ETH, 0)));
        console2.log("RedeemQueue (ETH) %s", address(vault.queueAt(TransferLibrary.ETH, 1)));

        vm.stopBroadcast();
        // revert("ok");
    }
}
