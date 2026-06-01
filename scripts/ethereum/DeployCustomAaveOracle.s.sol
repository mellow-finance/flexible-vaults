// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ChainlinkDecimalsAdapter} from "../../src/oracles/ChainlinkDecimalsAdapter.sol";

import "../common/PermissionedOracleFactory.sol";
import "./Constants.sol";

interface IPermissionedOracleFactory {
    struct InitParams {
        address owner;
        uint8 decimals;
        int256 initialAnswer;
        int256 minAllowedAnswer;
        int256 maxAllowedAnswer;
        string description;
    }
}

interface IAaveOracleFactory {
    struct InitParams {
        address fallbackOracle;
        address[] assets;
        address[] sources;
        IPermissionedOracleFactory.InitParams[] sourceParams;
        address baseCurrency;
        uint256 baseCurrencyUnit;
    }

    function create(InitParams calldata initParams) external returns (address oracle);
}

contract Deploy is Script {
    address public constant MELLOW_ORACLE_UPDATER = 0x836D6902B387A63D4b75Cc2490C251607bEA5b7E;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);

        IAaveOracleFactory factory = IAaveOracleFactory(0x00000000DDc33fB8d6F89dC5d9725F5e27B53D6f);

        address uspcSource = address(
            new ChainlinkDecimalsAdapter(
                0x02ae69C812DD749c32afb4F1723F6833EeF3d7a3, // USPC / USD (18 decimals)
                18,
                8,
                "USPC / USD"
            )
        );

        uint256 length = 1;
        address[] memory assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USPC));
        address[] memory sources = ArraysLibrary.makeAddressArray(abi.encode(uspcSource));

        IPermissionedOracleFactory.InitParams[] memory sourceParams =
            new IPermissionedOracleFactory.InitParams[](length);

        address aaveOracle = factory.create(
            IAaveOracleFactory.InitParams({
                fallbackOracle: 0x54586bE62E3c3580375aE3723C145253060Ca0C2,
                assets: assets,
                sources: sources,
                sourceParams: sourceParams,
                baseCurrency: address(0),
                baseCurrencyUnit: 1e8
            })
        );

        console.log(
            "price of %s == %s",
            IERC20Metadata(Constants.USPC).symbol(),
            IAaveOracle(aaveOracle).getAssetPrice(Constants.USPC)
        );
    }
}
