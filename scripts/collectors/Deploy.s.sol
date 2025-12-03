// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "./defi/CustomOracle.sol";

import "./defi/protocols/AaveCollector.sol";
import "./defi/protocols/ERC20Collector.sol";
import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";

import {Constants as MonadConstants} from "../monad/Constants.sol";

import {MVTCustomOracle} from "./defi/instances/MVTCustomOracle.sol";
import {rstETHPlusCustomOracle} from "./defi/instances/rstETHPlusCustomOracle.sol";
import {strETHCustomOracle} from "./defi/instances/strETHCustomOracle.sol";
import {tqETHCustomOracle} from "./defi/instances/tqETHCustomOracle.sol";

import {CoreVaultsCollector} from "./defi/protocols/CoreVaultsCollector.sol";
import {UniswapV3Collector} from "./defi/protocols/UniswapV3Collector.sol";

import {DistributionOracle} from "./defi/DistributionOracle.sol";

import {Deployment} from "./defi/Deployment.sol";

import {PriceOracle} from "./oracles/PriceOracle.sol";

import {rsETHOracle} from "./oracles/custom/rsETHOracle.sol";
import {rstETHOracle} from "./oracles/custom/rstETHOracle.sol";
import {weETHOracle} from "./oracles/custom/weETHOracle.sol";

contract Deploy is Script {
    function _deployStrETHCustomCollector() internal {
        strETHCustomOracle customOracle = new strETHCustomOracle();
        (address[] memory contracts, bytes[] memory bytecodes) = customOracle.stateOverrides();

        for (uint256 i = 0; i < contracts.length; i++) {
            string memory line =
                string(abi.encodePacked('"', vm.toString(contracts[i]), '": "', vm.toString(bytecodes[i]), '",'));
            console2.log(line);
        }
        // uint256 tvl = customOracle.tvl(EthereumConstants.STRETH, EthereumConstants.WETH);
        // console2.log("tvl:", tvl);
    }

    function _deployRstETHPlusCustomCollector() internal {
        rstETHPlusCustomOracle customOracle = new rstETHPlusCustomOracle(0x9aDadbFa5A6dA138E419Bc2fACb42364870bA8dC);
        customOracle.stateOverrides();

        uint256 tvl = customOracle.tvl(EthereumConstants.STRETH, EthereumConstants.WETH);
        console2.log("tvl:", tvl);
    }

    function _deployTqETHCustomCollector() internal {
        tqETHCustomOracle customOracle = new tqETHCustomOracle();
        customOracle.stateOverrides();

        ICustomOracle.Balance[] memory response =
            customOracle.getDistributions(0x2669a8B27B6f957ddb92Dc0ebdec1f112E6079E4, EthereumConstants.WETH);

        for (uint256 i = 0; i < response.length; i++) {
            console2.log(response[i].metadata, response[i].balance);
        }
    }

    function _deployMVTCustomCollector() internal {
        MVTCustomOracle customOracle = new MVTCustomOracle();
        customOracle.stateOverrides();
    }

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        _deployStrETHCustomCollector();

        revert("ok");
    }
}
