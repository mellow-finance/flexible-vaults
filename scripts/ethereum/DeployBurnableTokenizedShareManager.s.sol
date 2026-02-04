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
        vm.startBroadcast(deployerPk);

        BurnableTokenizedShareManager impl = new BurnableTokenizedShareManager{
            salt: 0xe98be1e5538fcbd716c506052eb1fd5d6fc495a321fb8675f917ee1fffab0080
        }(DEPLOYMENT_NAME, DEPLOYMENT_VERSION);

        console2.log(address(impl));
        vm.stopBroadcast();
        // revert("ok");
    }
}
