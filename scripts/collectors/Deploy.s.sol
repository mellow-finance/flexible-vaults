// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./Collector.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";

import {PriceOracle} from "./oracles/PriceOracle.sol";

contract Deploy is Script, Test {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        strETHToEthOracle o = new strETHToEthOracle();
        console.log(o.priceX96() * 1e18 / 2 ** 96);
    }
}

contract strETHToEthOracle {
    function priceX96() external view returns (uint256) {
        address v = EthereumConstants.STRETH;
        uint256 priceD18 = Vault(payable(v)).oracle().getReport(EthereumConstants.ETH).priceD18;
        return Math.mulDiv(2 ** 96, 1 ether, priceD18);
    }
}
