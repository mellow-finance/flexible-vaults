// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "./defi/CustomOracle.sol";

import "./defi/protocols/AaveCollector.sol";
import "./defi/protocols/ERC20Collector.sol";
import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "../ethereum/Constants.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        address deployer = vm.addr(deployerPk);
        Collector prev = Collector(0x94f2377dC4DC59f8641E4c3F9b2082B173d91ABC);
        Collector collectorImpl = new Collector();

        TransparentUpgradeableProxy c = new TransparentUpgradeableProxy(address(collectorImpl), deployer, "");
        Collector collector = Collector(address(c));
        collector.initialize(deployer, address(prev.oracle()));
        collector.collect(
            0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3,
            Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5)),
            Collector.Config({
                baseAssetFallback: address(0),
                oracleUpdateInterval: 24 hours,
                redeemHandlingInterval: 1 hours
            })
        );

        console2.log("collector: ", address(collector));

        if (true) {
            return;
        }
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
