// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Constants} from "./Constants.sol";
import {Script} from "forge-std/Script.sol";

import {AcceptanceLibrary} from "../common/AcceptanceLibrary.sol";
import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {ProtocolDeployment, ProtocolDeploymentLibrary} from "../common/ProtocolDeploymentLibrary.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        address proxyAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

        vm.startBroadcast(deployerPk);

        ProtocolDeployment memory deployment = ProtocolDeploymentLibrary.deploy(
            deployer,
            proxyAdmin,
            ProtocolDeploymentLibrary.DeploymentParams({
                cowswapSettlement: Constants.COWSWAP_SETTLEMENT,
                cowswapVaultRelayer: Constants.COWSWAP_VAULT_RELAYER,
                weth: Constants.WETH,
                minLeadingZeros: 8,
                salt: ArraysLibrary.makeBytes32Array(
                    abi.encode(
                        [
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3c84825df801fe3cddd000018,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a31fb8c57e5408f59f9b0100a8,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3dbd67913fc42eb9f5a040098,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3253648a35e86bb3769030024,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3eea2af40b4aadd8ee5048042,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3c9d6f6579a13328464050002,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a33a4f2e40558ea2c8680b000c
                        ],
                        [
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a33f3964b9658a37a1521c00c0,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3c381555325c0f512de020052,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a39d3fdfb6ba68aafba2070050,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a325a418919c68f29ffd060040,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a315de2307b2dc0a3b77020083,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a32edf144ba8e329a1c40c00c0
                        ],
                        [
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a341f6452bbf54509949090010,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a34cfc13261c78fa65f9140040,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3e28386d1049f1bd0e0016002,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3be5325ebffb99ef295040050,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3b9749c1f9b20d6de9d000030
                        ],
                        [
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3ec5e4cf2261f94efc60500a8,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a327064c975c06dbe66a1f4044,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3d49a92b364e8d5272505000d,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a31153e95f02680f466007000a
                        ],
                        [
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3ce2a1d03aa7114825a0a0040,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a3d318478af05f992e29068428,
                            0xe98be1e5538fcbd716c506052eb1fd5d6fc495a37ad1425a7b9c5d20490f0026
                        ]
                    )
                )
            })
        );

        vm.stopBroadcast();

        // AcceptanceLibrary.runProtocolDeploymentChecks(deployment);

        // revert("ok");
    }
}
