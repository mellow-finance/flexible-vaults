// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "../../src/utils/SwapModule.sol";
import "./Constants.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

        vm.startBroadcast(deployerPk);

        SwapModule impl = new SwapModule{salt: 0xe98be1e5538fcbd716c506052eb1fd5d6fc495a38d68cf46272e5289a2050048}(
            DEPLOYMENT_NAME,
            DEPLOYMENT_VERSION,
            address(0),
            address(0),
            Constants.WMON
        );

        IFactory swapModuleFactory =
            IFactory(Constants.protocolDeployment().factory.create(0, proxyAdmin, abi.encode(deployer)));

        swapModuleFactory.proposeImplementation(address(impl));
        swapModuleFactory.acceptProposedImplementation(address(impl));
        Ownable(address(swapModuleFactory)).transferOwnership(proxyAdmin);

        console.log("SwapModuleFactory", address(swapModuleFactory));
        console.log("SwapModule implementation", address(impl));


        vm.stopBroadcast();
        // revert("ok");
    }
}
