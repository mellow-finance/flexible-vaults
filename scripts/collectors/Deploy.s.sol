// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./defi/FEOracle.sol";
import "./defi/StrETHOracle.sol";
import "forge-std/Script.sol";
import "./Collector.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        Collector prev = Collector(0xE8a012C59c441d1790053bC1df87B23AAb6D1B67);
        Collector collector = new Collector(
            prev.owner(),
            address(prev.oracle()),
            0x5250Ae8A29A19DF1A591cB1295ea9bF2B0232453
        );

        console2.log("Collector: %s", address(collector));

        // address user = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
        // address vault = 0x277C6A642564A91ff78b008022D65683cEE5CCC5;

        // collector.collect(
        //     user,
        //     Vault(payable(vault)),
        //     Collector.Config({
        //         baseAssetFallback: address(type(uint160).max / 0xf * 0xe),
        //         oracleUpdateInterval: 24 hours,
        //         redeemHandlingInterval: 1 hours
        //     })    
        // );

        // revert("ok");
        // StrETHOracle.Balance[] memory b = strETHOracle.getDistributions(Vault(payable(vault)));
        // for (uint256 i = 0; i < b.length; i++) {
        //     console2.log(b[i].metadata, vm.toString(b[i].asset), vm.toString(b[i].balance));
        // }

        // console2.log(oracle.tvl(vault));
        // revert("ok");
    }
}
