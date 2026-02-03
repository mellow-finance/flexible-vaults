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

import {BtcEthOracle} from "./oracles/custom/BtcEthOracle.sol";
import {rsETHOracle} from "./oracles/custom/rsETHOracle.sol";
import {rstETHOracle} from "./oracles/custom/rstETHOracle.sol";
import {weETHOracle} from "./oracles/custom/weETHOracle.sol";

import {MUSDOraclePyth} from "./oracles/custom/MUSDOraclePyth.sol";

contract Deploy is Script, Test {
    PriceOracle oracle = PriceOracle(0x7c2ff214dab06cF3Ece494c0b2893219043b500f);

    function _deployMezoBTCCustomOracle() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        // address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);

        //BtcEthOracle customOracle = new BtcEthOracle(8);
        address[] memory tokens_ = new address[](3);
        PriceOracle.TokenOracle[] memory oracles_ = new PriceOracle.TokenOracle[](3);
        oracles_[0] = PriceOracle.TokenOracle({constValue: 0, oracle: address(new BtcEthOracle(18))});
        oracles_[1] = PriceOracle.TokenOracle({constValue: 0, oracle: address(new BtcEthOracle(8))});
        oracles_[2] = PriceOracle.TokenOracle({constValue: 0, oracle: address(new BtcEthOracle(8))});
        tokens_[0] = EthereumConstants.TBTC;
        tokens_[1] = EthereumConstants.WBTC;
        tokens_[2] = EthereumConstants.CBBTC;
        vm.stopBroadcast();

        vm.prank(0x58B38d079e904528326aeA2Ee752356a34AC1206);
        oracle.setOracles(tokens_, oracles_);

        console2.log("1 TBTC = %s USDC", oracle.getValue(EthereumConstants.TBTC, EthereumConstants.USDC, 1 ether));
        console2.log("1 WBTC = %s USDC", oracle.getValue(EthereumConstants.WBTC, EthereumConstants.USDC, 1e8));
        console2.log("1 CBBTC = %s USDC", oracle.getValue(EthereumConstants.CBBTC, EthereumConstants.USDC, 1e8));
        console2.logBytes(abi.encodeWithSelector(oracle.setOracles.selector, tokens_, oracles_));
    }

    address collector = 0x40DA86d29AF2fe980733bD54E364e7507505b41B;

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
        PriceOracle oracle = new PriceOracle(deployer);

        address[] memory tokens = new address[](4);
        tokens[0] = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590; // WETH
        tokens[1] = newImpl.ETH(); // rBTC
        tokens[2] = 0x967F8799aF07dF1534d48A95a5C9FEBE92c53AE0; // wrBTC
        tokens[3] = newImpl.USD();

        PriceOracle.TokenOracle[] memory oracles = new PriceOracle.TokenOracle[](4);
        oracles[0].constValue = 2 ** 96;
        oracles[1].oracle = address(new BtcToEthOracle());
        oracles[2].oracle = oracles[1].oracle;
        oracles[3].oracle = address(new UsdToEthOracle());

        oracle.setOracles(tokens, oracles);

        console2.log("Btc price:", oracle.getValue(tokens[1], tokens[3], 10 ** 18));
        console2.log("Eth price:", oracle.getValue(tokens[0], tokens[3], 10 ** 18));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(newImpl), deployer, abi.encodeCall(Collector.initialize, (deployer, address(oracle)))
        );

        Collector collector = Collector(address(proxy));

        console2.log("New collector impl:", address(newImpl));
        console2.log("Collector:", address(collector));

        // Collector(collector).collect(
        //     deployer,
        //     Vault(payable(0xdB58329eeBb999cbcC168086A71E5DAfc9CfaFB9)),
        //     Collector.Config({
        //         baseAssetFallback: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
        //         oracleUpdateInterval: 1 hours,
        //         redeemHandlingInterval: 1 hours
        //     })
        // );

        // revert("ok");
    }
}

import "./oracles/IAggregatorV3.sol";

// == Logs ==
//   Btc price: 9923966557
//   Eth price: 300446999999

contract UsdToEthOracle {
    address public constant aggregatorV3 = 0x3401DAF2b1f150Ef0c709Cc0283b5F2e55c3DF29;

    function priceX96() external view returns (uint256) {
        uint256 priceD8 = uint256(IAggregatorV3(aggregatorV3).latestAnswer());
        return Math.mulDiv(1 ether, 2 ** 96, priceD8);
    }
}

contract BtcToEthOracle {
    address public constant aggregatorV3BtcToUsd = 0x197225B3B017eb9b72Ac356D6B3c267d0c04c57c;
    address public constant aggregatorV3EthToUsd = 0x3401DAF2b1f150Ef0c709Cc0283b5F2e55c3DF29;

    function priceX96() external view returns (uint256) {
        uint256 priceBtcToUsd = uint256(IAggregatorV3(aggregatorV3BtcToUsd).latestAnswer());
        uint256 priceEthToUsd = uint256(IAggregatorV3(aggregatorV3EthToUsd).latestAnswer());
        return Math.mulDiv(1e3 * priceEthToUsd, 2 ** 96, priceBtcToUsd);
    }
}
