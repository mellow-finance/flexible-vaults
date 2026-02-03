// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "./Constants.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

        vm.startBroadcast(deployerPk);

        bytes memory bytecode =
            abi.encodePacked(type(RedeemQueue).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));

        bytes32 salt = 0xe98be1e5538fcbd716c506052eb1fd5d6fc495a37fb4a8690ba11a6a1c14001c;
        address instance = address(new RedeemQueue{salt: salt}(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));

        console2.log("RedeemQueue: %s", instance);

        vm.stopBroadcast();
        // revert("ok");
    }
}
