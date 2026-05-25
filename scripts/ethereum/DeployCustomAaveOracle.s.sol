// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

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

        uint256 length = 5;
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.SRUSDE, Constants.FRXUSD, Constants.MSUSD, Constants.PENDLE, Constants.WFRAX)
        );
        address[] memory sources = ArraysLibrary.makeAddressArray(
            abi.encode(
                address(0),
                0x9B4a96210bc8D9D55b1908B465D8B0de68B7fF83, // https://data.chain.link/feeds/ethereum/mainnet/frxusd-usd
                address(0),
                address(0),
                0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f // https://data.chain.link/feeds/ethereum/mainnet/fxs-usd
            )
        );

        IPermissionedOracleFactory.InitParams[] memory sourceParams =
            new IPermissionedOracleFactory.InitParams[](length);
        sourceParams[0] = IPermissionedOracleFactory.InitParams({
            owner: MELLOW_ORACLE_UPDATER,
            decimals: 8,
            initialAnswer: 101823846,
            minAllowedAnswer: 1.01e8,
            maxAllowedAnswer: 1.1e8,
            description: "srUSDe / USD"
        });
        sourceParams[2] = IPermissionedOracleFactory.InitParams({
            owner: MELLOW_ORACLE_UPDATER,
            decimals: 8,
            initialAnswer: 0.9967e8,
            minAllowedAnswer: 0.98e8,
            maxAllowedAnswer: 1e8,
            description: "msUSD / USD"
        });
        sourceParams[3] = IPermissionedOracleFactory.InitParams({
            owner: MELLOW_ORACLE_UPDATER,
            decimals: 8,
            initialAnswer: 126396000,
            minAllowedAnswer: 0,
            maxAllowedAnswer: 10e8,
            description: "PENDLE / USD"
        });

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

        address[] memory allAssets = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.USDC,
                Constants.USDT,
                Constants.USDE,
                Constants.SUSDE,
                Constants.SRUSDE,
                Constants.FRXUSD,
                Constants.MSUSD,
                Constants.PENDLE,
                Constants.WFRAX
            )
        );
        for (uint256 i = 0; i < allAssets.length; i++) {
            console.log(
                "price of %s == %s",
                IERC20Metadata(allAssets[i]).symbol(),
                IAaveOracle(aaveOracle).getAssetPrice(allAssets[i])
            );
        }
    }
}
