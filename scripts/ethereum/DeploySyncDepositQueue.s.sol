// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "./Constants.sol";

interface IF {
    function safeCreate2(bytes32 salt, bytes calldata initializationCode)
        external
        payable
        returns (address deploymentAddress);
}

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

        vm.startBroadcast(deployerPk);

        bytes memory bytecode =
            abi.encodePacked(type(SyncDepositQueue).creationCode, abi.encode(DEPLOYMENT_NAME, DEPLOYMENT_VERSION));
        address instance = IF(0x0000000000FFe8B47B3e2130213B802212439497).safeCreate2(
            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a31f80ea8ecdc2d1140a0f00c0, bytecode
        );
        console2.log("SyncDepositQueue: %s", instance);

        vm.stopBroadcast();
        // revert("ok");
    }
}
