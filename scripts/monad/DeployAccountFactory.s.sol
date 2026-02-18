// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

import "../../src/accounts/MellowAccountV1.sol";
import "./Constants.sol";

contract Deploy is Script {
    string public constant DEPLOYMENT_NAME = "Mellow";
    uint256 public constant DEPLOYMENT_VERSION = 1;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

        vm.startBroadcast(deployerPk);
        address impl =
            address(new MellowAccountV1{salt: 0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3e10885251bd1dcac7f350030}());

        IFactory accountFactory =
            IFactory(Constants.protocolDeployment().factory.create(0, proxyAdmin, abi.encode(deployer)));

        accountFactory.proposeImplementation(address(impl));
        accountFactory.acceptProposedImplementation(address(impl));
        Ownable(address(accountFactory)).transferOwnership(proxyAdmin);

        console.log("MellowAccount factory", address(accountFactory));
        console.log("MellowAccountV1 implementation", address(impl));

        vm.stopBroadcast();
        // revert("ok");
    }
}
