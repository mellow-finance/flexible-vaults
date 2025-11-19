// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/collectors/Collector.sol";

import "../../scripts/collectors/defi/external/IAaveOracleV3.sol";
import "../../scripts/collectors/oracles/PriceOracle.sol";

import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "./Constants.sol";

contract AaveOracle is ICustomPriceOracle {
    uint256 public immutable Q96 = 2 ** 96;

    address public aaveOracle;
    address public asset;

    constructor(address aaveOracle_, address asset_) {
        aaveOracle = aaveOracle_;
        asset = asset_;
    }

    function priceX96() public view returns (uint256) {
        return IAaveOracleV3(aaveOracle).getAssetPrice(asset) * Q96;
    }
}

contract Deploy is Script {
    uint256 constant Q96 = 2 ** 96;
    address public vault = 0x8769b724e264D38d0d70eD16F965FA9Fa680EcDe;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        address deployer = vm.addr(deployerPk);

        PriceOracle oracle = new PriceOracle(deployer);
        PriceOracle.TokenOracle[] memory tokenOracles = new PriceOracle.TokenOracle[](5);

        tokenOracles[0] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.WETH))
        }); // MON
        tokenOracles[1] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.WETH))
        }); // WMON
        tokenOracles[2] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.WBTC))
        }); // WBTC
        tokenOracles[3] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.USDC))
        }); // USDC
        tokenOracles[4] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveOracle(Constants.AAVE_V3_ORACLE, Constants.USDT))
        }); // USDT

        oracle.setOracles(
            ArraysLibrary.makeAddressArray(
                abi.encode(Constants.ETH, Constants.WETH, Constants.WBTC, Constants.USDC, Constants.USDT)
            ),
            tokenOracles
        );

        Collector Impl = new Collector();
        Collector collector = Collector(payable(new TransparentUpgradeableProxy(address(Impl), deployer, new bytes(0))));
        collector.initialize(deployer, address(oracle));
        console2.log("Collector", address(collector));

        tokenOracles = new PriceOracle.TokenOracle[](1);
        tokenOracles[0] = PriceOracle.TokenOracle({constValue: 1e8 * Q96, oracle: address(0)}); // USD
        oracle.setOracles(ArraysLibrary.makeAddressArray(abi.encode(collector.USD())), tokenOracles);
        vm.stopBroadcast();

        collector.collect(
            address(0),
            Vault(payable(vault)),
            Collector.Config({
                baseAssetFallback: Constants.WETH,
                oracleUpdateInterval: 24 hours,
                redeemHandlingInterval: 1 hours
            })
        );
        revert("ok");
    }
}
