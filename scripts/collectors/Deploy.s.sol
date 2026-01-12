// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Collector.sol";
import "./defi/CustomOracle.sol";

import "./defi/protocols/AaveCollector.sol";
import "./defi/protocols/ERC20Collector.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants as EthereumConstants} from "../ethereum/Constants.sol";
import {Constants as MonadConstants} from "../monad/Constants.sol";
import {Constants as PlasmaConstants} from "../plasma/Constants.sol";

import {MVTCustomOracle} from "./defi/instances/MVTCustomOracle.sol";
import {rstETHPlusCustomOracle} from "./defi/instances/rstETHPlusCustomOracle.sol";
import {strETHCustomOracle} from "./defi/instances/strETHCustomOracle.sol";
import {strETHPlasmaCustomOracle} from "./defi/instances/strETHPlasmaCustomOracle.sol";
import {tqETHCustomOracle} from "./defi/instances/tqETHCustomOracle.sol";

import {CoreVaultsCollector} from "./defi/protocols/CoreVaultsCollector.sol";
import {UniswapV3Collector} from "./defi/protocols/UniswapV3Collector.sol";

import {DistributionOracle} from "./defi/DistributionOracle.sol";

import {Deployment} from "./defi/Deployment.sol";

import {PriceOracle} from "./oracles/PriceOracle.sol";

import {rsETHOracle} from "./oracles/custom/rsETHOracle.sol";
import {rstETHOracle} from "./oracles/custom/rstETHOracle.sol";
import {weETHOracle} from "./oracles/custom/weETHOracle.sol";

contract Deploy is Script, Test {
    function _deployStrETHCustomCollector() internal {
        strETHCustomOracle customOracle =
            new strETHCustomOracle(address(EthereumConstants.protocolDeployment().swapModuleFactory));
        (address[] memory contracts, bytes[] memory bytecodes) = customOracle.stateOverrides();

        for (uint256 i = 0; i < contracts.length; i++) {
            string memory line =
                string(abi.encodePacked('"', vm.toString(contracts[i]), '": "', vm.toString(bytecodes[i]), '",'));
            console2.log(line);
        }

        // ICustomOracle.Balance[] memory balances =
        //     customOracle.getDistributions(EthereumConstants.STRETH, EthereumConstants.WETH);
        // for (uint256 i = 0; i < balances.length; i++) {
        //     console2.log(
        //         "subvault=%s, asset=%s, balance=%s",
        //         balances[i].holder,
        //         balances[i].asset,
        //         vm.toString(balances[i].balance)
        //     );
        // }
        // console2.log("tvl:", tvl);
    }

    function _deployStrETHPlasmaCustomCollector() internal {
        strETHPlasmaCustomOracle customOracle =
            new strETHPlasmaCustomOracle(address(PlasmaConstants.protocolDeployment().swapModuleFactory));

        // console2.log(
        //     customOracle.tvl(
        //         PlasmaConstants.STRETH, PlasmaConstants.WETH)
        // );

        ICustomOracle.Balance[] memory balances =
            customOracle.getDistributions(PlasmaConstants.STRETH, PlasmaConstants.WETH);
        for (uint256 i = 0; i < balances.length; i++) {
            console2.log(
                "subvault=%s, asset=%s, balance=%s",
                balances[i].holder,
                balances[i].asset,
                vm.toString(balances[i].balance)
            );
        }
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

        Collector newImpl = new Collector();
        address collector = 0x40DA86d29AF2fe980733bD54E364e7507505b41B;
        address proxyAdmin = 0xe51cE5816901AA302eBD1CC764C2Bb87c72CBa69;
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(collector), address(newImpl), "");

        console2.log("New collector impl:", address(newImpl));

        // Collector(collector).collect(
        //     deployer,
        //     Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5)),
        //     Collector.Config({
        //         baseAssetFallback: address(0),
        //         oracleUpdateInterval: 1 hours,
        //         redeemHandlingInterval: 1 hours
        //     })
        // );

        // revert("ok");
    }
}
