// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArraysLibrary} from "../common/ArraysLibrary.sol";
import {Constants} from "./Constants.sol";

import {Collector} from "../collectors/Collector.sol";

import {IAaveOracleV3} from "../collectors/defi/external/IAaveOracleV3.sol";
import {ICustomPriceOracle} from "../collectors/oracles/ICustomPriceOracle.sol";
import {PriceOracle} from "../collectors/oracles/PriceOracle.sol";

import {Vault} from "../../src/vaults/Vault.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice ICustomPriceOracle wrapper: quotes `asset` in 8-decimal USD via the Aave V3 oracle.
/// @dev priceX96 = getAssetPrice(asset) * Q96 * 10^(18 - decimals). Aave here reports USD prices with
///      BASE_CURRENCY_UNIT = 1e8, so paired with the PriceOracle's USD anchor (1e18 * Q96) the
///      normalize-to-18-decimals factor makes getValue(token, USD, raw) render 8-decimal USD
///      (mainnet Collector scale) for tokens of any decimals (18-dec HYPE, 6-dec stables).
contract AaveAssetOracle is ICustomPriceOracle {
    uint256 private constant Q96 = 2 ** 96;

    IAaveOracleV3 public immutable aaveOracle;
    address public immutable asset;
    uint256 public immutable scaleX96; // Q96 * 10^(18 - decimals)

    constructor(address aaveOracle_, address asset_) {
        aaveOracle = IAaveOracleV3(aaveOracle_);
        asset = asset_;
        scaleX96 = Q96 * 10 ** (18 - IERC20Metadata(asset_).decimals());
    }

    function priceX96() external view returns (uint256) {
        return aaveOracle.getAssetPrice(asset) * scaleX96;
    }
}

/// @notice Deploys the read-only Collector + its PriceOracle on the Hyper chain.
/// @dev Prices HYPE / WHYPE / wstHYPE (all 18-decimal) off the Aave V3 oracle behind the lending
///      deployment 0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b. HYPE is the native placeholder and
///      shares WHYPE's oracle. USD is the constant numeraire anchor; getValue renders 8-decimal USD.
contract Deploy is Script {
    uint256 constant Q96 = 2 ** 96;

    /// @dev priceX96(USD) numeraire anchor => getValue(token, USD, raw) renders 8-decimal USD.
    uint256 constant STABLE_PRICE_X96 = 1e18 * Q96;

    /// @dev Aave V3 oracle for the Hyper lending deployment (Pool 0x00A89d..1A8b ->
    ///      AddressesProvider 0x72c9..170C -> getPriceOracle()). USD-quoted, BASE_CURRENCY_UNIT = 1e8.
    address constant AAVE_ORACLE = 0xC9Fb4fbE842d57EAc1dF3e641a281827493A630e;

    /// @dev 1/2 msig Andrei, Anthony. TODO: confirm this Safe exists on Hyper before broadcasting.
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

        // 3) Deploy the token price-source oracles and configure the PriceOracle.
        (address[] memory tokens, PriceOracle.TokenOracle[] memory tokenOracles) = _buildTokenOracles();
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
        console.log("HYPE    $ (1e8) %s", oracle.getValue(Constants.HYPE, usd, 1e18));
        console.log("WHYPE   $ (1e8) %s", oracle.getValue(Constants.WHYPE, usd, 1e18));
        console.log("wstHYPE $ (1e8) %s", oracle.getValue(Constants.wstHYPE, usd, 1e18));
        console.log("USDC    $ (1e8) %s", oracle.getValue(Constants.USDC, usd, 1e6));
        console.log("USDT0   $ (1e8) %s", oracle.getValue(Constants.USDT0, usd, 1e6));
        console.log("-------------------------------------------------------------");
        console.log("Gas used        %s cents", gasUsed * 36e9 / 1e16);

        // Smoke test (fill in the deployed vault, then uncomment):
        // collector.collect(
        //     address(0),
        //     Vault(payable(0x0000000000000000000000000000000000000000)),
        //     Collector.Config({baseAssetFallback: Constants.WHYPE, oracleUpdateInterval: 1 days, redeemHandlingInterval: 1 hours})
        // );
    }

    /// @notice Deploys fresh Hyper price-source oracles and prints the raw calldata for the OWNER msig
    ///         to call PriceOracle.setOracles(...). Standalone: touches neither the Collector nor the
    ///         live PriceOracle. Run with: forge script ... --sig "setOraclesCalldata()" [--broadcast]
    function setOraclesCalldata() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));

        vm.startBroadcast(deployerPk);
        (address[] memory tokens, PriceOracle.TokenOracle[] memory tokenOracles) = _buildTokenOracles();
        vm.stopBroadcast();

        console.log("setOracles calldata (target = PriceOracle):");
        console.logBytes(abi.encodeCall(PriceOracle.setOracles, (tokens, tokenOracles)));
    }

    /// @dev Deploys the Hyper Aave-backed oracles and builds the setOracles(tokens, oracles) args.
    ///      USD is the constant numeraire anchor. HYPE (native) reuses the WHYPE oracle. All three HYPE
    ///      tokens are 18-decimal, so getValue(token, USD, raw) renders 8-decimal USD (mainnet scale).
    function _buildTokenOracles()
        internal
        returns (address[] memory tokens, PriceOracle.TokenOracle[] memory tokenOracles)
    {
        address usd = address(bytes20(keccak256("usd-token-address"))); // == Collector.USD()
        tokens = ArraysLibrary.makeAddressArray(
            abi.encode(usd, Constants.HYPE, Constants.WHYPE, Constants.wstHYPE, Constants.USDC, Constants.USDT0)
        );

        // One WHYPE oracle, shared by native HYPE and WHYPE.
        address whypeOracle = address(new AaveAssetOracle(AAVE_ORACLE, Constants.WHYPE));

        tokenOracles = new PriceOracle.TokenOracle[](6);
        tokenOracles[0] = PriceOracle.TokenOracle({constValue: STABLE_PRICE_X96, oracle: address(0)}); // USD
        tokenOracles[1] = PriceOracle.TokenOracle({constValue: 0, oracle: whypeOracle}); // HYPE (native) -> WHYPE
        tokenOracles[2] = PriceOracle.TokenOracle({constValue: 0, oracle: whypeOracle}); // WHYPE
        tokenOracles[3] = PriceOracle.TokenOracle({
            constValue: 0,
            oracle: address(new AaveAssetOracle(AAVE_ORACLE, Constants.wstHYPE))
        }); // wstHYPE
        tokenOracles[4] =
            PriceOracle.TokenOracle({constValue: 0, oracle: address(new AaveAssetOracle(AAVE_ORACLE, Constants.USDC))}); // USDC
        tokenOracles[5] =
            PriceOracle.TokenOracle({constValue: 0, oracle: address(new AaveAssetOracle(AAVE_ORACLE, Constants.USDT0))}); // USDT0
    }
}
