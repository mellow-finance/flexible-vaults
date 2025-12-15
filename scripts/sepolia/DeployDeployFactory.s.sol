// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "scripts/sepolia/Constants.sol";
import "src/DeployVaultFactory.sol";
import "src/DeployVaultFactoryRegistry.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        ProtocolDeployment memory $ = Constants.protocolDeployment();

        vm.startBroadcast(deployerPk);

        DeployVaultFactoryRegistry registry = new DeployVaultFactoryRegistry();
        OracleSubmitterFactory oracleSubmitterFactory = new OracleSubmitterFactory();
        DeployVaultFactory deployVaultFactory = new DeployVaultFactory(
            address($.vaultConfigurator), address($.verifierFactory), address(oracleSubmitterFactory), address(registry)
        );
        vm.stopBroadcast();

        console2.log("DeployVaultFactoryRegistry deployed at:", address(registry));
        console2.log("        DeployVaultFactory deployed at:", address(deployVaultFactory));
    }
}
