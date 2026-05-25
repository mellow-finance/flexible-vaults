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

        uint256 length = 2;
        address[] memory assets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDAI, Constants.SUSDAI));
        address[] memory sources = ArraysLibrary.makeAddressArray(
            abi.encode(
                0xF3d6b05E69918d71807Ab005791daCcEC5de8C78, // https://data.chain.link/feeds/arbitrum/mainnet/usdai-usd
                address(0)
            )
        );

        IPermissionedOracleFactory.InitParams[] memory sourceParams =
            new IPermissionedOracleFactory.InitParams[](length);
        sourceParams[1] = IPermissionedOracleFactory.InitParams({
            owner: MELLOW_ORACLE_UPDATER,
            decimals: 8,
            initialAnswer: 107953695,
            minAllowedAnswer: 107000000,
            maxAllowedAnswer: 117000000,
            description: "sUSDai / USD"
        });

        address aaveOracle = factory.create(
            IAaveOracleFactory.InitParams({
                fallbackOracle: Constants.AAVE_V3_ORACLE,
                assets: assets,
                sources: sources,
                sourceParams: sourceParams,
                baseCurrency: address(0),
                baseCurrencyUnit: 1e8
            })
        );

        console.log("custom AaveOracle:", aaveOracle);

        address[] memory allAssets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC, Constants.USDAI, Constants.SUSDAI));
        for (uint256 i = 0; i < allAssets.length; i++) {
            console.log(
                "price of %s == %s",
                IERC20Metadata(allAssets[i]).symbol(),
                IAaveOracle(aaveOracle).getAssetPrice(allAssets[i])
            );
        }
        // revert("ok");
    }
}
