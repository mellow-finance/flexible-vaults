// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        Collector collector =
            new Collector(0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3, 0x3032f5eCf95B2F8FA216Df50d588E2aAe4256f33);
        collector.collect(
            0x85C205b7Dd8EAd3a288feF72E7e6681E524F1575,
            Vault(payable(0x85C205b7Dd8EAd3a288feF72E7e6681E524F1575)),
            Collector.Config(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1 hours, 1 hours)
        );
    }
}
