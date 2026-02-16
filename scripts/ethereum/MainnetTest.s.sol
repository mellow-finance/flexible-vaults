// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "./test/DummyReporter.sol";

contract Deploy is Script {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant ETH = TransferLibrary.ETH;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        VaultConfigurator vaultConfigurator = VaultConfigurator(0x0000000294F847c9DE7dFa668965f37F277C96ca);

        DummyReporter dummyReporter = new DummyReporter();

        Vault.RoleHolder[] memory holders = new Vault.RoleHolder[](17);
        holders[0] = Vault.RoleHolder(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"), deployer);
        holders[1] = Vault.RoleHolder(keccak256("oracles.Oracle.ACCEPT_REPORT_ROLE"), deployer);
        holders[2] = Vault.RoleHolder(keccak256("modules.VaultModule.CREATE_SUBVAULT_ROLE"), deployer);
        holders[3] = Vault.RoleHolder(keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE"), deployer);
        holders[4] = Vault.RoleHolder(keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE"), deployer);
        holders[5] = Vault.RoleHolder(keccak256("permissions.Verifier.SET_MERKLE_ROOT_ROLE"), deployer);
        holders[6] = Vault.RoleHolder(keccak256("permissions.Verifier.CALLER_ROLE"), deployer);
        holders[7] = Vault.RoleHolder(keccak256("permissions.Verifier.ALLOW_CALL_ROLE"), deployer);
        holders[8] = Vault.RoleHolder(keccak256("permissions.Verifier.DISALLOW_CALL_ROLE"), deployer);
        holders[9] = Vault.RoleHolder(keccak256("modules.ShareModule.CREATE_QUEUE_ROLE"), deployer);
        holders[10] = Vault.RoleHolder(keccak256("managers.RiskManager.SET_VAULT_LIMIT_ROLE"), deployer);
        holders[11] = Vault.RoleHolder(keccak256("managers.RiskManager.SET_SUBVAULT_LIMIT_ROLE"), deployer);
        holders[12] = Vault.RoleHolder(keccak256("managers.RiskManager.ALLOW_SUBVAULT_ASSETS_ROLE"), deployer);
        holders[13] = Vault.RoleHolder(keccak256("managers.RiskManager.MODIFY_VAULT_BALANCE_ROLE"), deployer);
        holders[14] = Vault.RoleHolder(keccak256("managers.RiskManager.MODIFY_SUBVAULT_BALANCE_ROLE"), deployer);

        holders[15] = Vault.RoleHolder(keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE"), address(dummyReporter));
        holders[16] = Vault.RoleHolder(keccak256("oracles.Oracle.ACCEPT_REPORT_ROLE"), address(dummyReporter));

        address[] memory assets_ = new address[](3);
        assets_[0] = WSTETH;
        assets_[1] = WETH;
        assets_[2] = ETH;

        (,,,, address vault_) = vaultConfigurator.create(
            VaultConfigurator.InitParams({
                version: 0,
                proxyAdmin: deployer,
                vaultAdmin: deployer,
                shareManagerVersion: 0,
                shareManagerParams: abi.encode(bytes32(0), "Mellow test stRATEGY", "tstRATEGY"),
                feeManagerVersion: 0,
                feeManagerParams: abi.encode(deployer, deployer, uint24(0), uint24(0), uint24(1e5), uint24(1e4)),
                riskManagerVersion: 0,
                riskManagerParams: abi.encode(int256(1000 ether)),
                oracleVersion: 0,
                oracleParams: abi.encode(
                    IOracle.SecurityParams({
                        maxAbsoluteDeviation: 0.001 ether,
                        suspiciousAbsoluteDeviation: 0.0005 ether,
                        maxRelativeDeviationD18: 0.001 ether,
                        suspiciousRelativeDeviationD18: 0.0005 ether,
                        timeout: 10 minutes,
                        depositInterval: 1 minutes,
                        redeemInterval: 1 minutes
                    }),
                    assets_
                ),
                defaultDepositHook: address(0x00000006E67B164e7Cc41B47B6Ba5C910439937A),
                defaultRedeemHook: address(0x0000000dF279885951d71269d649513564E326bc),
                queueLimit: 4,
                roleHolders: holders
            })
        );

        Vault vault = Vault(payable(vault_));

        vault.createQueue(0, true, deployer, WSTETH, new bytes(0));
        vault.createQueue(0, true, deployer, WETH, new bytes(0));
        vault.createQueue(0, true, deployer, ETH, new bytes(0));
        vault.createQueue(0, false, deployer, WSTETH, new bytes(0));

        vault.feeManager().setBaseAsset(vault_, WSTETH);

        dummyReporter.push(vault);

        IDepositQueue(vault.queueAt(ETH, 0)).deposit{value: 1 gwei}(1 gwei, deployer, new bytes32[](0));

        console.log("Vault:", vault_);
        console.log("DepositQueue WSTETH:", vault.queueAt(WSTETH, 0));
        console.log("DepositQueue WETH:", vault.queueAt(WETH, 0));
        console.log("DepositQueue ETH:", vault.queueAt(ETH, 0));
        console.log("RedeemQueue WSTETH:", vault.queueAt(WSTETH, 1));

        console.log("Dummy reporter:", address(dummyReporter));
        vm.stopBroadcast();
        // revert("ok");
    }
}
