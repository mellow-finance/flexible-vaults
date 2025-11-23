// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/collectors/Collector.sol";

import "../../scripts/collectors/defi/external/IAaveOracleV3.sol";
import "../../scripts/collectors/oracles/PriceOracle.sol";

import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "./Constants.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract AaveOracle is ICustomPriceOracle {
    uint256 public immutable Q96 = 2 ** 96;

    address public aaveOracle;
    address public asset;

    constructor(address aaveOracle_, address asset_) {
        aaveOracle = aaveOracle_;
        asset = asset_;
    }

    function priceX96() public view returns (uint256) {
        if (asset == Constants.SHMON) {
            uint256 assetPrice = IAaveOracleV3(aaveOracle).getAssetPrice(Constants.WMON);
            uint256 shmonPrice = IERC4626(address(Constants.SHMON)).convertToAssets(1 ether);
            return (assetPrice * shmonPrice / 1 ether) * Q96;
        }
        return IAaveOracleV3(aaveOracle).getAssetPrice(asset) * Q96;
    }
}

contract Deploy is Script {
    uint256 constant Q96 = 2 ** 96;
    address public vault = 0x912644cdFadA93469b8aB5b4351bDCFf61691613;
    address public collectorAddress = 0x3228e80512eC98A23430Ee9c3feC937b351D1427;

    function run() external {
        addPriceOracle();
        //revert("ok");
    }

    function addPriceOracle() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        PriceOracle oracle = PriceOracle(address(Collector(payable(collectorAddress)).oracle()));

        PriceOracle.TokenOracle[] memory tokenOracles = new PriceOracle.TokenOracle[](1);
        tokenOracles[0] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.SHMON))
        }); // SHMON

        vm.startBroadcast(deployerPk);
        address deployer = vm.addr(deployerPk);

        oracle.setOracles(ArraysLibrary.makeAddressArray(abi.encode(Constants.SHMON)), tokenOracles);

        vm.stopBroadcast();
        oracle.priceX96(Constants.SHMON);
    }

    function deployCollector() internal {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        address deployer = vm.addr(deployerPk);

        PriceOracle oracle = new PriceOracle(deployer);
        PriceOracle.TokenOracle[] memory tokenOracles = new PriceOracle.TokenOracle[](2);

        tokenOracles[0] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.WMON))
        }); // MON
        tokenOracles[1] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.WMON))
        }); // WMON

        oracle.setOracles(ArraysLibrary.makeAddressArray(abi.encode(Constants.MON, Constants.WMON)), tokenOracles);

        Collector Impl = new Collector();
        Collector collector = Collector(payable(new TransparentUpgradeableProxy(address(Impl), deployer, new bytes(0))));
        collector.initialize(deployer, address(oracle));
        console2.log("Collector", address(collector));

        tokenOracles = new PriceOracle.TokenOracle[](1);
        tokenOracles[0] = PriceOracle.TokenOracle({constValue: 1e18 * Q96, oracle: address(0)}); // USD
        oracle.setOracles(ArraysLibrary.makeAddressArray(abi.encode(collector.USD())), tokenOracles);
        vm.stopBroadcast();

        collector.collect(
            address(0),
            Vault(payable(vault)),
            Collector.Config({
                baseAssetFallback: Constants.WMON,
                oracleUpdateInterval: 20 hours,
                redeemHandlingInterval: 1 hours
            })
        );
    }
}
