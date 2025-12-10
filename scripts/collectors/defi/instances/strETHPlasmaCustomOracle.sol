// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomOracle.sol";

import {ArraysLibrary} from "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../plasma/Constants.sol";
import {ERC20Collector} from "../protocols/ERC20Collector.sol";
import {FluidCollector} from "../protocols/FluidCollector.sol";
import {strETHPlasmaCustomAaveOracle} from "../strETHPlasmaCustomAaveOracle.sol";

contract strETHPlasmaCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    ERC20Collector public immutable erc20Collector;
    FluidCollector public immutable fluidCollector;
    strETHPlasmaCustomAaveOracle public immutable strETHOracle;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(impl, customOracle, erc20Collector, fluidCollector, strETHOracle, address(this))
        );
        bytecodes = new bytes[](6);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(erc20Collector).code;
        bytecodes[3] = address(fluidCollector).code;
        bytecodes[4] = address(strETHOracle).code;
        bytecodes[5] = address(this).code;
    }

    constructor(address swapModuleFactory) {
        strETHOracle = new strETHPlasmaCustomAaveOracle();
        impl = new CustomOracle(address(strETHOracle), Constants.WXPL);
        erc20Collector = new ERC20Collector(swapModuleFactory);
        fluidCollector = new FluidCollector(Constants.FLUID_VAULT_T1_RESOLVER);

        address[] memory protocols = new address[](2);
        protocols[0] = address(erc20Collector);
        protocols[1] = address(fluidCollector);

        bytes[] memory protocolDeployments = new bytes[](2);
        protocolDeployments[1] = abi.encode(Constants.STRETH_FLUID_WSTUSR_USDT0_NFT_ID);

        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.WSTUSR, Constants.WSTETH, Constants.USDT0, Constants.WXPL)
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
