// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "./defi/StrETHOracle.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        // Collector prev = Collector(0xE8a012C59c441d1790053bC1df87B23AAb6D1B67);
        // Collector collector = new Collector(prev.owner(), address(prev.oracle()));
        StrETHOracle o = new StrETHOracle();
        o.getDistributions(Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5)), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        // console2.log("Collector: %s", address(collector));
        revert("ok");

        // collector.collect(
        //     0x0000000000000000000000000000000000000000,
        //     Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5)),
        //     Collector.Config({
        //         baseAssetFallback: address(0),
        //         oracleUpdateInterval: 24 hours,
        //         redeemHandlingInterval: 1 hours
        //     })
        // );
        // revert("ok");

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
