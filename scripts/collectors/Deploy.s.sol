// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";
import {Constants as HyperConstants} from "../hyper/Constants.sol";
import {Constants as MezoConstants} from "../mezo/Constants.sol";

import {Collector} from "./Collector.sol";

import {Vault} from "../../src/vaults/Vault.sol";
import {AggregatorBasedOracle} from "./oracles/AggregatorBasedOracle.sol";
import {PriceOracle} from "./oracles/PriceOracle.sol";

import {MezoBTCOracle} from "./oracles/custom/MezoBTCOracle.sol";

import {MezoCbBTCOracle} from "./oracles/custom/MezoCbBTCOracle.sol";
import {MezoMUSDOracle} from "./oracles/custom/MezoMUSDOracle.sol";
import {MezoUSDCOracle} from "./oracles/custom/MezoUSDCOracle.sol";
import {MezoUSDOracle} from "./oracles/custom/MezoUSDOracle.sol";
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
        /* Collector(0x328761856aA6F615DE35210297C150B51Ffb539d).collect(
            address(0),
            Vault(payable(0x07AFFA6754458f88db83A72859948d9b794E131b)),
            Collector.Config(MezoConstants.MUSD, 1 days, 1 days)
        ); */

        // revert("ok");

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
        address btcOracle = address(new MezoBTCOracle());
        address usdOracle = address(new MezoUSDOracle());

        console2.log("% MezoCbBTCOracle: %", MezoConstants.mcbBTC, cbbtcOracle);
        console2.log("% MezoMUSDOracle: %", MezoConstants.MUSD, musdOracle);
        console2.log("% MezoUSDCOracle: %", MezoConstants.mUSDC, usdcOracle);
        console2.log("% MezoUSDTOracle: %", MezoConstants.mUSDT, usdtOracle);
        console2.log("% MezoBTCOracle: %", MezoConstants.BTC, btcOracle);
        console2.log("% MezoUSDOracle: %", 0x78cE8E00eF7eBA6FaBb1C98ED1Fa0F69D13c595F, usdOracle);
        vm.stopBroadcast();

        address[] memory tokens = new address[](6);
        tokens[0] = MezoConstants.mcbBTC;
        tokens[1] = MezoConstants.MUSD;
        tokens[2] = MezoConstants.mUSDC;
        tokens[3] = MezoConstants.mUSDT;
        tokens[4] = MezoConstants.BTC;
        tokens[5] = 0x78cE8E00eF7eBA6FaBb1C98ED1Fa0F69D13c595F;
        PriceOracle.TokenOracle[] memory oracles = new PriceOracle.TokenOracle[](6);
        oracles[0] = PriceOracle.TokenOracle(0, cbbtcOracle);
        oracles[1] = PriceOracle.TokenOracle(0, musdOracle);
        oracles[2] = PriceOracle.TokenOracle(0, usdcOracle);
        oracles[3] = PriceOracle.TokenOracle(0, usdtOracle);
        oracles[4] = PriceOracle.TokenOracle(0, btcOracle);
        oracles[5] = PriceOracle.TokenOracle(0, usdOracle);
        console2.logBytes(abi.encodeCall(PriceOracle.setOracles, (tokens, oracles)));
    }
}
