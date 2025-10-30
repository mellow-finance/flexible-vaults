// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "./defi/CustomOracle.sol";

import "./defi/protocols/AaveCollector.sol";
import "./defi/protocols/ERC20Collector.sol";
import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "../ethereum/Constants.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        // Collector prev = Collector(0xE8a012C59c441d1790053bC1df87B23AAb6D1B67);
        // Collector collector = new Collector(prev.owner(), address(prev.oracle()));
        // address[] memory protocols_,
        // bytes[] memory protocolDeployments_,
        // address[] memory assets_,
        // address aaveOracle_,
        // address nativeWrapper_

        address erc20Collector = address(new ERC20Collector());
        address aaveCollector = address(new AaveCollector());
        address[] memory protocols = new address[](3);
        protocols[0] = address(erc20Collector);
        protocols[1] = address(aaveCollector);
        protocols[2] = address(aaveCollector);

        bytes[] memory protocolDeployments = new bytes[](3);
        protocolDeployments[1] = abi.encode(
            AaveCollector.ProtocolDeployment({pool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, metadata: "Core"})
        );
        protocolDeployments[2] = abi.encode(
            AaveCollector.ProtocolDeployment({pool: 0x4e033931ad43597d96D6bcc25c280717730B58B1, metadata: "Prime"})
        );

        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.ETH,
                Constants.WETH,
                Constants.WSTETH,
                Constants.USDC,
                Constants.USDT,
                Constants.USDS,
                Constants.USDE,
                Constants.SUSDE
            )
        );

        CustomOracle impl =
            new CustomOracle(0x54586bE62E3c3580375aE3723C145253060Ca0C2, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        address o = Clones.cloneWithImmutableArgs(address(impl), abi.encode(protocols, protocolDeployments, assets));

        console2.log("erc20Collector:", erc20Collector);
        console2.logBytes(erc20Collector.code);

        console2.log("aaveCollector:", aaveCollector);
        console2.logBytes(aaveCollector.code);

        console2.log("impl:", address(impl));
        console2.logBytes(address(impl).code);

        console2.log("Collector", address(o));
        console2.logBytes(o.code);

        // CustomOracle(o).getDistributions(
        //     0x277C6A642564A91ff78b008022D65683cEE5CCC5, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        // );
        // console2.log("Collector: %s", address(collector));
        revert("ok");

        // collector.collect(
        //     0x0000000000000000000000000000000000000000,
        //     Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5)),
        //     Collector.Config({
        //         baseAssetFallback: address(0),
        //         oracleUpdateInterval: 24 hours,
        //         redeemHandlingInterval: 1 hours
        //     })
        // );
        // revert("ok");

        // address user = 0xE98Be1E5538FCbD716C506052eB1Fd5d6fC495A3;
        // address vault = 0x277C6A642564A91ff78b008022D65683cEE5CCC5;

        // collector.collect(
        //     user,
        //     Vault(payable(vault)),
        //     Collector.Config({
        //         baseAssetFallback: address(type(uint160).max / 0xf * 0xe),
        //         oracleUpdateInterval: 24 hours,
        //         redeemHandlingInterval: 1 hours
        //     })
        // );

        // revert("ok");
        // StrETHOracle.Balance[] memory b = strETHOracle.getDistributions(Vault(payable(vault)));
        // for (uint256 i = 0; i < b.length; i++) {
        //     console2.log(b[i].metadata, vm.toString(b[i].asset), vm.toString(b[i].balance));
        // }

        // console2.log(oracle.tvl(vault));
        // revert("ok");
    }
}
