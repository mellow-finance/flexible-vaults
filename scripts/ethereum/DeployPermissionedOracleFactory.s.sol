// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "../common/PermissionedOracleFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        bytes32 salt = bytes32(0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3c9f5155b3c2ce4b204000008);
        PermissionedOracleFactory factory = new PermissionedOracleFactory{salt: salt}();

        console.log(address(factory));
        require(address(factory) == 0x00000000997F2b310f903832f5379E9A4ACCBdD6);
    }
}
