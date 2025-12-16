// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomOracle.sol";

import "../protocols/AaveCollector.sol";
import "../protocols/ERC20Collector.sol";
import "../protocols/ResolvCollector.sol";

import "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../ethereum/Constants.sol";

import {strETHCustomAaveOracle} from "../strETHCustomAaveOracle.sol";

contract strETHCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    ERC20Collector public immutable erc20Collector;
    AaveCollector public immutable aaveCollector;
    ResolvCollector public immutable resolvCollector;
    strETHCustomAaveOracle public immutable strETHOracle;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(impl, customOracle, erc20Collector, aaveCollector, resolvCollector, strETHOracle, address(this))
        );
        bytecodes = new bytes[](7);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(erc20Collector).code;
        bytecodes[3] = address(aaveCollector).code;
        bytecodes[4] = address(resolvCollector).code;
        bytecodes[5] = address(strETHOracle).code;
        bytecodes[6] = address(this).code;
    }

    constructor(address swapModuleFactory) {
        strETHOracle = new strETHCustomAaveOracle();
        impl = new CustomOracle(address(strETHOracle), Constants.WETH);
        erc20Collector = new ERC20Collector(swapModuleFactory);
        aaveCollector = new AaveCollector();
        resolvCollector =
            new ResolvCollector(Constants.USDC, Constants.USDT, Constants.USR, Constants.USR_REQUEST_MANAGER);

        address[] memory protocols = new address[](5);
        protocols[0] = address(erc20Collector);
        protocols[1] = address(aaveCollector);
        protocols[2] = address(aaveCollector);
        protocols[3] = address(aaveCollector);
        protocols[4] = address(resolvCollector);

        bytes[] memory protocolDeployments = new bytes[](5);
        protocolDeployments[1] =
            abi.encode(AaveCollector.ProtocolDeployment({pool: Constants.AAVE_CORE, metadata: "Core"}));
        protocolDeployments[2] =
            abi.encode(AaveCollector.ProtocolDeployment({pool: Constants.AAVE_PRIME, metadata: "Prime"}));
        protocolDeployments[3] =
            abi.encode(AaveCollector.ProtocolDeployment({pool: Constants.SPARK, metadata: "SparkLend"}));

        address[] memory assets = ArraysLibrary.makeAddressArray(
            abi.encode(
                Constants.ETH,
                Constants.WETH,
                Constants.WSTETH,
                Constants.USDC,
                Constants.USDT,
                Constants.USDS,
                Constants.USDE,
                Constants.SUSDE,
                Constants.USR,
                Constants.STUSR,
                Constants.WSTUSR
            )
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

    function tvlMultiChain(
        address vault,
        address denominator,
        address[] calldata otherAssets,
        int256[] calldata otherBalances
    ) public view returns (uint256 value) {
        return customOracle.tvlMultiChain(vault, denominator, otherAssets, otherBalances);
    }

    function getDistributions(address vault_, address denominator)
        public
        view
        returns (ICustomOracle.Balance[] memory response)
    {
        return customOracle.getDistributions(vault_, denominator);
    }
}
