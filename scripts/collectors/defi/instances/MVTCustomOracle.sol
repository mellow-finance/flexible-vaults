// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Clones, CustomOracle, ICustomOracle} from "../CustomOracle.sol";

import {ERC20Collector} from "../protocols/ERC20Collector.sol";
import {ERC4626Collector} from "../protocols/ERC4626Collector.sol";

import {ArraysLibrary} from "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../monad/Constants.sol";

contract MVTCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    ERC20Collector public immutable erc20Collector;
    ERC4626Collector public immutable erc4626Collector;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(impl, customOracle, erc20Collector, erc4626Collector, address(this))
        );
        bytecodes = new bytes[](5);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(erc20Collector).code;
        bytecodes[3] = address(erc4626Collector).code;
        bytecodes[4] = address(this).code;
    }

    constructor() {
        impl = new CustomOracle(Constants.AAVE_V3_ORACLE, Constants.WMON);
        erc20Collector = new ERC20Collector();
        erc4626Collector = new ERC4626Collector();

        address[] memory protocols = ArraysLibrary.makeAddressArray(abi.encode(erc20Collector, erc4626Collector));

        bytes[] memory protocolDeployments = new bytes[](2);
        protocolDeployments[1] = abi.encode(
            ArraysLibrary.makeAddressArray(
                abi.encode(
                    Constants.MORPHO_STEAKHOUSE_USDC,
                    Constants.MORPHO_STEAKHOUSE_USDT,
                    Constants.MORPHO_STEAKHOUSE_MON,
                    Constants.MORPHO_STEAKHOUSE_AUSD
                )
            )
        );

        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.MON, Constants.WMON, Constants.USDC, Constants.USDT0, Constants.AUSD)
        );

        customOracle = CustomOracle(
            Clones.cloneWithImmutableArgs(address(impl), abi.encode(protocols, protocolDeployments, assets))
        );
    }

    function tvl(address vault, ICustomOracle.Data calldata data) public view returns (uint256 value) {
        return customOracle.tvl(vault, data);
    }

    function tvl(address vault, address denominator) public view returns (uint256 value) {
        return customOracle.tvl(vault, denominator);
    }

    function getDistributions(address vault_, address denominator)
        public
        view
        returns (ICustomOracle.Balance[] memory response)
    {
        return customOracle.getDistributions(vault_, denominator);
    }
}
