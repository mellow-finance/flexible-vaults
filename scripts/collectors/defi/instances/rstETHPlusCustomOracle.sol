// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomOracle.sol";

import "../protocols/CapLenderCollector.sol";
import "../protocols/ERC20Collector.sol";
import "../protocols/ResolvCollector.sol";
import "../protocols/SymbioticCollector.sol";

import "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../ethereum/Constants.sol";

contract rstETHPlusCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    ERC20Collector public immutable erc20Collector;
    SymbioticCollector public immutable symbioticCollector;
    ResolvCollector public immutable resolvCollector;
    CapLenderCollector public immutable capLenderCollector;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(
                impl,
                customOracle,
                erc20Collector,
                symbioticCollector,
                resolvCollector,
                capLenderCollector,
                address(this)
            )
        );
        bytecodes = new bytes[](7);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(erc20Collector).code;
        bytecodes[3] = address(symbioticCollector).code;
        bytecodes[4] = address(resolvCollector).code;
        bytecodes[5] = address(capLenderCollector).code;
        bytecodes[6] = address(this).code;
    }

    constructor(address symbioticVault) {
        impl = new CustomOracle(Constants.AAVE_V3_ORACLE, Constants.WETH);

        erc20Collector = new ERC20Collector();
        symbioticCollector = new SymbioticCollector();
        resolvCollector =
            new ResolvCollector(Constants.USDC, Constants.USDT, Constants.USR, Constants.USR_REQUEST_MANAGER);
        capLenderCollector = new CapLenderCollector(Constants.CAP_LENDER);

        address[] memory protocols = ArraysLibrary.makeAddressArray(
            abi.encode(erc20Collector, symbioticCollector, resolvCollector, capLenderCollector)
        );

        bytes[] memory protocolDeployments = new bytes[](4);
        protocolDeployments[1] = abi.encode(symbioticVault);
        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(Constants.ETH, Constants.WETH, Constants.WSTETH, Constants.USDC, Constants.USR, Constants.STUSR)
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
