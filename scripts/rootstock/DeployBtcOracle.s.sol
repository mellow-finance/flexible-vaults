// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {Collector} from "../collectors/Collector.sol";
import {ICustomPriceOracle} from "../collectors/oracles/ICustomPriceOracle.sol";
import {PriceOracle} from "../collectors/oracles/PriceOracle.sol";
import {RootstockBTCOracle} from "../collectors/oracles/custom/RootstockBTCOracle.sol";
import {RootstockUSDOracle} from "../collectors/oracles/custom/RootstockUSDOracle.sol";

import {Vault} from "../../src/vaults/Vault.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DeployBtcOracle is Script {
    uint256 internal constant Q96 = 2 ** 96;

    address public constant PRICE_ORACLE = 0x96f30aBCcD1ffd62a4A35CE389Af4D8893f4831B;
    address public constant COLLECTOR = 0x6753B3Cb6D50888A5FF908c9DD15f6919DdE0BF1;
    address public constant TYR_RBTC_VAULT = 0x97Bb1d1b9FaA1091406A005F0B4a1658e5b542Eb;

    address public constant RBTC = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WRBTC_REGISTERED = 0x967F8799aF07dF1534d48A95a5C9FEBE92c53AE0; // "Wrapped RBTC"
    address public constant WRBTC_CANONICAL = 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d; // "Wrapped BTC"
    address public constant WETH = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address public constant USD = address(bytes20(keccak256("usd-token-address")));

    function run() external {
        require(block.chainid == 30, "DeployBtcOracle: not rootstock");

        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));

        _logTvl("TVL before:");

        vm.startBroadcast(deployerPk);
        address btcOracle = address(new RootstockBTCOracle());
        address usdOracle = address(new RootstockUSDOracle());
        vm.stopBroadcast();

        // Prices every freshly deployed oracle in USD, so a wrong decimal factor is visible before wiring.
        uint256 btcPriceD8 = _logUsdPrice("RootstockBTCOracle:", btcOracle, usdOracle, 18);
        uint256 usdPriceD8 = _logUsdPrice("RootstockUSDOracle:", usdOracle, usdOracle, 8);
        require(btcPriceD8 > 1_000e8 && btcPriceD8 < 1_000_000e8, "DeployBtcOracle: implausible btc price");
        require(usdPriceD8 == 1e8, "DeployBtcOracle: usd is not worth one dollar");

        bytes memory calldata_ = _setOraclesCalldata(btcOracle, usdOracle);

        // Local preview only: applied to the in-memory fork, outside of any broadcast, so it is never sent.
        vm.prank(PriceOracle(PRICE_ORACLE).owner());
        (bool success,) = PRICE_ORACLE.call(calldata_);
        require(success, "DeployBtcOracle: setOracles preview failed");
        _logTvl("TVL after (simulated locally, NOT broadcast):");

        console2.log("PriceOracle to configure:", PRICE_ORACLE);
        console2.log("setOracles calldata (send later, from the PriceOracle owner):");
        console2.logBytes(calldata_);
    }

    /// @dev Mirrors what the points backend reads: `collect` on the live collector for the Tyr rBTC vault.
    ///      Today it reverts with 0x4f319ffe (the RedStone ETH feed staleness guard), which is why the API
    ///      serves a zero TVL.
    function _logTvl(string memory label) internal view {
        console2.log(label);
        Collector.Config memory config = Collector.Config({
            baseAssetFallback: RBTC,
            oracleUpdateInterval: 1 days,
            redeemHandlingInterval: 1 hours
        });
        try Collector(COLLECTOR).collect(address(0), Vault(payable(TYR_RBTC_VAULT)), config) returns (
            Collector.Response memory r
        ) {
            console2.log("  totalLP:", r.totalLP);
            console2.log("  totalBase:", r.totalBase);
            console2.log("  lpPriceBase:", r.lpPriceBase);
            console2.log("  totalUSD (8 decimals):", r.totalUSD);
            console2.log("  lpPriceUSD (8 decimals):", r.lpPriceUSD);
        } catch (bytes memory reason) {
            console2.log("  collect() reverted:");
            console2.logBytes(reason);
        }
    }

    /// @dev Value of one whole token, in USD with 8 decimals: priceX96(token) / priceX96(USD).
    ///      Reverts if the BTC feed is stale, i.e. before anything gets wired up.
    function _logUsdPrice(string memory name, address oracle, address usdOracle, uint256 tokenDecimals)
        internal
        view
        returns (uint256 priceD8)
    {
        uint256 priceX96 = ICustomPriceOracle(oracle).priceX96();
        uint256 usdX96 = ICustomPriceOracle(usdOracle).priceX96();
        require(priceX96 != 0 && usdX96 != 0, "DeployBtcOracle: zero price");

        priceD8 = Math.mulDiv(priceX96, 10 ** tokenDecimals, usdX96);
        console2.log(name, oracle);
        console2.log("  priceX96:", priceX96);
        console2.log("  price in USD (8 decimals):", priceD8);
    }

    /// @dev Re-bases the oracle from ETH to RBTC:
    ///      - RBTC and both WRBTC deployments become the unit of account;
    ///      - the USD pseudo-token points at the freshly deployed BTC-backed oracle;
    ///      - WETH is unregistered, its only source was the dead ETH feed and no Rootstock vault uses it.
    function _setOraclesCalldata(address btcOracle, address usdOracle) internal pure returns (bytes memory) {
        address[] memory tokens = new address[](5);
        tokens[0] = RBTC;
        tokens[1] = WRBTC_REGISTERED;
        tokens[2] = WRBTC_CANONICAL;
        tokens[3] = USD;
        tokens[4] = WETH;

        PriceOracle.TokenOracle[] memory oracles = new PriceOracle.TokenOracle[](5);
        oracles[0] = PriceOracle.TokenOracle(0, btcOracle);
        oracles[1] = PriceOracle.TokenOracle(0, btcOracle);
        oracles[2] = PriceOracle.TokenOracle(0, btcOracle);
        oracles[3] = PriceOracle.TokenOracle(0, usdOracle);
        oracles[4] = PriceOracle.TokenOracle(0, address(0));

        return abi.encodeCall(PriceOracle.setOracles, (tokens, oracles));
    }
}
