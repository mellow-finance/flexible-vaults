// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        Collector c = new Collector(address(1), address(1));
    }
}
