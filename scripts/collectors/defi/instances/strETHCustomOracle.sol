// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomOracle.sol";

import "../protocols/AaveCollector.sol";
import "../protocols/ERC20Collector.sol";

import "../../../common/ArraysLibrary.sol";
import {Constants} from "../../../ethereum/Constants.sol";

import {strETHCustomAaveOracle} from "../strETHCustomAaveOracle.sol";

contract strETHCustomOracle {
    CustomOracle public immutable impl;
    CustomOracle public immutable customOracle;
    ERC20Collector public immutable erc20Collector;
    AaveCollector public immutable aaveCollector;
    strETHCustomAaveOracle public immutable customAaveOracleImpl;
    strETHCustomAaveOracle public immutable customAaveOracle;

    function stateOverrides() public view returns (address[] memory contracts, bytes[] memory bytecodes) {
        contracts = ArraysLibrary.makeAddressArray(
            abi.encode(
                impl, customOracle, erc20Collector, aaveCollector, customAaveOracleImpl, customAaveOracle, address(this)
            )
        );
        bytecodes = new bytes[](7);
        bytecodes[0] = address(impl).code;
        bytecodes[1] = address(customOracle).code;
        bytecodes[2] = address(erc20Collector).code;
        bytecodes[3] = address(aaveCollector).code;
        bytecodes[4] = address(customAaveOracleImpl).code;
        bytecodes[5] = address(customAaveOracle).code;
        bytecodes[6] = address(this).code;
    }

    constructor() {
        {
            customAaveOracleImpl = new strETHCustomAaveOracle(Constants.AAVE_V3_ORACLE);
            address[] memory aggregatedAssets = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDC));
            address[] memory aggregators = ArraysLibrary.makeAddressArray(abi.encode(Constants.USDT_CHAINLINK_ORACLE));
            address[][] memory aggregatedSources = new address[][](aggregatedAssets.length);
            for (uint256 i = 0; i < aggregatedSources.length; i++) {
                aggregatedSources[i] = aggregators;
            }
            customAaveOracle = strETHCustomAaveOracle(
                Clones.cloneWithImmutableArgs(
                    address(customAaveOracleImpl), abi.encode(aggregatedAssets, aggregatedSources)
                )
            );
        }
        impl = new CustomOracle(address(customAaveOracle), Constants.WETH);
        erc20Collector = new ERC20Collector();
        aaveCollector = new AaveCollector();

        address[] memory protocols = new address[](4);
        protocols[0] = address(erc20Collector);
        protocols[1] = address(aaveCollector);
        protocols[2] = address(aaveCollector);
        protocols[3] = address(aaveCollector);

        bytes[] memory protocolDeployments = new bytes[](4);
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
                Constants.SUSDE
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

    function getDistributions(address vault_, address denominator)
        public
        view
        returns (ICustomOracle.Balance[] memory response)
    {
        return customOracle.getDistributions(vault_, denominator);
    }
}
