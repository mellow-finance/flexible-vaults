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

        SwapModule impl = new SwapModule{salt: 0xe98be1e5538fcbd716c506052eb1fd5d6fc495a30234670de60b69b8f51e0030}(
            DEPLOYMENT_NAME,
            DEPLOYMENT_VERSION,
            Constants.COWSWAP_SETTLEMENT,
            Constants.COWSWAP_VAULT_RELAYER,
            Constants.WETH
        );

        IFactory swapModuleFactory =
            IFactory(Constants.protocolDeployment().factory.create(0, deployer, abi.encode(deployer)));

        swapModuleFactory.proposeImplementation(address(impl));
        swapModuleFactory.acceptProposedImplementation(address(impl));
        Ownable(address(swapModuleFactory)).transferOwnership(proxyAdmin);

        console2.log("SwapModuleFactory", address(swapModuleFactory));
        console2.log("SwapModule implementation", address(impl));

        vm.stopBroadcast();
        // revert("ok");
    }
}
