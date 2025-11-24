// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomOracle.sol";

import {CoreVaultsCollector} from "../protocols/CoreVaultsCollector.sol";
import {UniswapV3Collector} from "../protocols/UniswapV3Collector.sol";

import "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../ethereum/Constants.sol";

contract tqETHCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    CoreVaultsCollector public immutable coreVaultsCollector;
    UniswapV3Collector public immutable uniswapV3Collector;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(impl, customOracle, coreVaultsCollector, uniswapV3Collector, address(this))
        );
        bytecodes = new bytes[](5);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(coreVaultsCollector).code;
        bytecodes[3] = address(uniswapV3Collector).code;
        bytecodes[4] = address(this).code;
    }

    constructor() {
        impl = new CustomOracle(Constants.AAVE_V3_ORACLE, Constants.WETH);

        coreVaultsCollector = new CoreVaultsCollector();
        uniswapV3Collector = new UniswapV3Collector(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

        address[] memory protocols = new address[](2);
        protocols[0] = address(coreVaultsCollector);
        protocols[1] = address(uniswapV3Collector);

        bytes[] memory protocolDeployments = new bytes[](2);
        protocolDeployments[0] =
            abi.encode(0x277C6A642564A91ff78b008022D65683cEE5CCC5, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        protocolDeployments[1] = abi.encode(
            ArraysLibrary.makeAddressArray(abi.encode(address(0))), // whitelisted uniswap v3 pools
            abi.encode(
                15 minutes, // timespan
                50 // max tick deviation
            )
        );

        address[] memory assets =
            ArraysLibrary.makeAddressArray(abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH));

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
