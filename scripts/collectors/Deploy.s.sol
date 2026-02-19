// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./Collector.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";
import {Constants as HyperConstants} from "../hyper/Constants.sol";

import {Collector} from "./Collector.sol";

import {AggregatorBasedOracle} from "./oracles/AggregatorBasedOracle.sol";
import {PriceOracle} from "./oracles/PriceOracle.sol";

interface IAaveOracle {
    function getSourceOfAsset(address) external view returns (address);
}

contract Deploy is Script, Test {
    address public immutable USD = address(bytes20(keccak256("usd-token-address")));
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        IAaveOracle aaveOracle = IAaveOracle(0xC9Fb4fbE842d57EAc1dF3e641a281827493A630e);

        address eth = 0xBe6727B535545C67d5cAa73dEa54865B92CF7907;
        address usd = address(0);
        address usdc = HyperConstants.USDC;

        PriceOracle oracle = new PriceOracle(deployer);
        oracle.setOracle(ETH, address(0), 2 ** 96);
        oracle.setOracle(
            USD,
            address(new AggregatorBasedOracle(aaveOracle.getSourceOfAsset(usd), aaveOracle.getSourceOfAsset(eth), 18)),
            0
        );
        oracle.setOracle(
            HyperConstants.USDC,
            address(new AggregatorBasedOracle(aaveOracle.getSourceOfAsset(usdc), aaveOracle.getSourceOfAsset(eth), 12)),
            0
        );

        // console.log(oracle.priceX96(ETH));
        // console.log(oracle.priceX96(USD));
        // console.log(oracle.priceX96(usdc));

        // console.log(oracle.getValue(ETH, USD, 1 ether));
        // console.log(oracle.getValue(USD, USD, 1e8));
        // console.log(oracle.getValue(HyperConstants.USDC, USD, 1e6));

        Collector impl = new Collector();
        Collector collector = Collector(
            address(
                new TransparentUpgradeableProxy(
                    address(impl), deployer, abi.encodeCall(Collector.initialize, (deployer, address(oracle)))
                )
            )
        );
        console.log(address(collector));
        // revert("ok");
    }
}
