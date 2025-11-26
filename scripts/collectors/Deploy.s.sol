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
        customOracle.stateOverrides();

        uint256 tvl = customOracle.tvl(EthereumConstants.STRETH, EthereumConstants.WETH);
        console2.log("tvl:", tvl);
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

        PriceOracle oracle = PriceOracle(0x7c2ff214dab06cF3Ece494c0b2893219043b500f);

        PriceOracle.TokenOracle[] memory oracles = new PriceOracle.TokenOracle[](3);
        oracles[0].oracle = address(new rstETHOracle());
        oracles[1].oracle = address(new rsETHOracle());
        oracles[2].oracle = address(new weETHOracle());

        address[] memory tokens = ArraysLibrary.makeAddressArray(
            abi.encode(
                0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7,
                0x7a4EffD87C2f3C55CA251080b1343b605f327E3a,
                0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee
            )
        );

        oracle.setOracles(tokens, oracles);
        // oracle.priceX96(tokens[0]);
        // oracle.priceX96(tokens[1]);
        // oracle.priceX96(tokens[2]);

        oracle.transferOwnership(0x58B38d079e904528326aeA2Ee752356a34AC1206);
        // revert("ok");
    }
}
