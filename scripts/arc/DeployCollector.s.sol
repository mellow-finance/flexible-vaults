// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "./Constants.sol";

import {Collector} from "../collectors/Collector.sol";
import {AggregatorBasedOracle} from "../collectors/oracles/AggregatorBasedOracle.sol";
import {PriceOracle} from "../collectors/oracles/PriceOracle.sol";

import {Vault} from "../../src/vaults/Vault.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Deploys the read-only Collector + its PriceOracle on the Arc chain.
/// @dev Arc is USDC-only and USDC is a $1 stablecoin, so both USDC and the synthetic USD token
///      are priced with a constant 1:1 oracle (no external feed exists on Arc). Their ratio drives
///      every getValue()/priceX96() conversion in the Collector, so 1:1 renders USD == base value.
///      Add real ICustomPriceOracle sources here if non-stable assets are ever added to the vault.
contract Deploy is Script {
    uint256 constant Q96 = 2 ** 96;

    /// @dev priceX96(USD) numeraire anchor. With decimalShift = 26 - tokenDecimals - feedDecimals on
    ///      each token feed, getValue(token, USD, raw) renders 8-decimal USD (mainnet Collector scale).
    uint256 constant STABLE_PRICE_X96 = 1e18 * Q96;

    /// @dev Arc Chainlink (EACAggregatorProxy) USD-quote feeds, all 8-decimal answers.
    address constant USDC_USD_FEED = 0x84EA90AC252Dc437031461836DB5164219147905; // "USDC / USD"
    address constant EURC_USD_FEED = 0x361b95c10b76Ca3f35C686d423e43A951755Bf23; // "EURC / USD"
    address constant BTC_USD_FEED = 0xa109B535C70C8Be9995be64Bb6751AcDB27e03De; // "BTC / USD" (cirBTC)

    /// @dev 1/2 msig Andrei, Anthony
    address constant OWNER = 0xF6Dad2E83fA810795c3714Bb8F367659235556e4;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        uint256 gasBefore = gasleft();

        // 1) USD-display price oracle. Owned by the deployer first so we can configure it in-line,
        //    then handed over to OWNER.
        PriceOracle oracle = new PriceOracle(deployer);

        // 2) Collector implementation + proxy, initialized with (owner, oracle).
        Collector impl = new Collector();
        Collector collector = Collector(
            payable(
                new TransparentUpgradeableProxy(
                    address(impl), OWNER, abi.encodeCall(Collector.initialize, (OWNER, address(oracle)))
                )
            )
        );

        // 3) Configure prices. USD is the constant 18-decimal numeraire anchor; USDC, EURC and cirBTC
        //    read live Chainlink USD feeds via AggregatorBasedOracle (aggregator1 = address(0) => /USD).
        //    decimalShift = 36 - tokenDecimals - feedDecimals(8): USDC/EURC (6 dec) -> 22, cirBTC (8 dec) -> 20.
        address[] memory tokens =
            ArraysLibrary.makeAddressArray(abi.encode(collector.USD(), Constants.USDC, Constants.EURC, Constants.cirBTC));
        PriceOracle.TokenOracle[] memory tokenOracles = new PriceOracle.TokenOracle[](4);
        tokenOracles[0] = PriceOracle.TokenOracle({constValue: STABLE_PRICE_X96, oracle: address(0)}); // USD
        tokenOracles[1] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AggregatorBasedOracle(USDC_USD_FEED, address(0), 22))
        }); // USDC
        tokenOracles[2] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AggregatorBasedOracle(EURC_USD_FEED, address(0), 22))
        }); // EURC
        tokenOracles[3] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AggregatorBasedOracle(BTC_USD_FEED, address(0), 20))
        }); // cirBTC
        oracle.setOracles(tokens, tokenOracles);

        // 4) Hand the oracle to the final admin.
        oracle.transferOwnership(OWNER);

        uint256 gasUsed = gasBefore - gasleft();

        vm.stopBroadcast();

        console.log("PriceOracle     %s", address(oracle));
        console.log("Collector impl  %s", address(impl));
        console.log("Collector proxy %s", address(collector));

        // Log configured prices (USD value of 1 whole token, 8-decimal USD, mainnet scale).
        address usd = collector.USD();
        console.log("-------------------------------------------------------------");
        console.log("USDC   $ (1e8)  %s", oracle.getValue(Constants.USDC, usd, 1e6));
        console.log("EURC   $ (1e8)  %s", oracle.getValue(Constants.EURC, usd, 1e6));
        console.log("cirBTC $ (1e8)  %s", oracle.getValue(Constants.cirBTC, usd, 1e8));
        console.log("-------------------------------------------------------------");
        console.log("Gas used        %s cents", gasUsed * 36e9 / 1e16);

        // Smoke test (fill in the deployed vault, then uncomment):
        // collector.collect(
        //     address(0),
        //     Vault(payable(0x0000000000000000000000000000000000000000)),
        //     Collector.Config({baseAssetFallback: Constants.USDC, oracleUpdateInterval: 1 days, redeemHandlingInterval: 1 hours})
        // );
       // revert("success");
    }
}
