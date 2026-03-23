// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";
import {Constants as HyperConstants} from "../hyper/Constants.sol";
import {Constants as MezoConstants} from "../mezo/Constants.sol";

import {Collector} from "../../src/collector/Collector.sol";

import {AggregatorBasedOracle} from "./oracles/AggregatorBasedOracle.sol";
import {PriceOracle} from "../../src/collector/oracles/PriceOracle.sol";

import {MezoBTCOracle} from "./oracles/custom/MezoBTCOracle.sol";
import {MezoCbBTCOracle} from "./oracles/custom/MezoCbBTCOracle.sol";
import {MezoMUSDOracle} from "./oracles/custom/MezoMUSDOracle.sol";
import {MezoUSDCOracle} from "./oracles/custom/MezoUSDCOracle.sol";
import {MezoUSDTOracle} from "./oracles/custom/MezoUSDTOracle.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IAaveOracle {
    function getSourceOfAsset(address) external view returns (address);
}

contract Deploy is Script, Test {
    address public immutable USD = address(bytes20(keccak256("usd-token-address")));
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function run() external {
        _deployMezoOracles();

        //revert("ok");

        // IAaveOracle aaveOracle = IAaveOracle(0xC9Fb4fbE842d57EAc1dF3e641a281827493A630e);

        // address eth = 0xBe6727B535545C67d5cAa73dEa54865B92CF7907;
        // address usd = address(0);
        // address usdc = HyperConstants.USDC;

        // PriceOracle oracle = new PriceOracle(deployer);
        // oracle.setOracle(ETH, address(0), 2 ** 96);
        // oracle.setOracle(
        //     USD,
        //     address(new AggregatorBasedOracle(aaveOracle.getSourceOfAsset(usd), aaveOracle.getSourceOfAsset(eth), 18)),
        //     0
        // );
        // oracle.setOracle(
        //     HyperConstants.USDC,
        //     address(new AggregatorBasedOracle(aaveOracle.getSourceOfAsset(usdc), aaveOracle.getSourceOfAsset(eth), 12)),
        //     0
        // );

        // console.log(oracle.priceX96(ETH));
        // console.log(oracle.priceX96(USD));
        // console.log(oracle.priceX96(usdc));

        // console.log(oracle.getValue(ETH, USD, 1 ether));
        // console.log(oracle.getValue(USD, USD, 1e8));
        // console.log(oracle.getValue(HyperConstants.USDC, USD, 1e6));

        // Collector impl = new Collector();
        // Collector collector = Collector(
        //     address(
        //         new TransparentUpgradeableProxy(
        //             address(impl), deployer, abi.encodeCall(Collector.initialize, (deployer, address(oracle)))
        //         )
        //     )
        // );
        // console.log(address(collector));
        // revert("ok");
    }

    function deployMezo() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address owner = 0x1615932d3E6743bFe6bBa3a6f81E477b06191860;
        vm.startBroadcast(deployerPk);

        PriceOracle priceOracle = new PriceOracle(deployer);
        priceOracle.transferOwnership(owner);

        Collector collectorImpl = new Collector();
        Collector collector = Collector(
            address(
                new TransparentUpgradeableProxy(
                    address(collectorImpl), owner, abi.encodeCall(Collector.initialize, (owner, address(priceOracle)))
                )
            )
        );

        console2.log("PriceOracle:", address(priceOracle));
        console2.log("Collector impl:", address(collectorImpl));
        console2.log("Collector proxy:", address(collector));

        vm.stopBroadcast();
    }

    function _deployMezoOracles() internal {

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        // address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        address cbbtcOracle = address(new MezoCbBTCOracle());
        address musdOracle = address(new MezoMUSDOracle());
        address usdcOracle = address(new MezoUSDCOracle());
        address usdtOracle = address(new MezoUSDTOracle());

        console2.log("% MezoCbBTCOracle: %", MezoConstants.mcbBTC, cbbtcOracle);
        console2.log("% MezoMUSDOracle: %", MezoConstants.MUSD, musdOracle);
        console2.log("% MezoUSDCOracle: %", MezoConstants.mUSDC, usdcOracle);
        console2.log("% MezoUSDTOracle: %", MezoConstants.mUSDT, usdtOracle);
        vm.stopBroadcast();

        address[] memory tokens = new address[](4);
        tokens[0] = MezoConstants.mcbBTC;
        tokens[1] = MezoConstants.MUSD;
        tokens[2] = MezoConstants.mUSDC;
        tokens[3] = MezoConstants.mUSDT;
        PriceOracle.TokenOracle[] memory oracles = new PriceOracle.TokenOracle[](4);
        oracles[0] = PriceOracle.TokenOracle(0, cbbtcOracle);
        oracles[1] = PriceOracle.TokenOracle(0, musdOracle);
        oracles[2] = PriceOracle.TokenOracle(0, usdcOracle);
        oracles[3] = PriceOracle.TokenOracle(0, usdtOracle);
        console2.logBytes(abi.encodeCall(PriceOracle.setOracles, (
            tokens,
            oracles
        )));
    }
}
