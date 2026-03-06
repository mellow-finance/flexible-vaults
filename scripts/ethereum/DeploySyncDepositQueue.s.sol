// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "./Constants.sol";
import "scripts/common/interfaces/Imports.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        bytes32 salt = bytes32(0xe98be1e5538fcbd716c506052eb1fd5d6fc495a30ebd93b475ef8e28937c0040);
        address instance = address(new SyncDepositQueue{salt: salt}(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
        console.log("SyncDepositQueue: %s", instance);
        vm.stopBroadcast();
        // revert("ok");
    }
}
