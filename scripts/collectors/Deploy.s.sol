// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        Collector collector =
            new Collector(0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3, 0x7c2ff214dab06cF3Ece494c0b2893219043b500f);
        collector.collect(
            0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            Vault(payable(0xe3143Cfcfa5cB5e438c64B6EB03087445eEaCCDc)),
            Collector.Config(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, 1 hours, 1 hours)
        );
    }
}
