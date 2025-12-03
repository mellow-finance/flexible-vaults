// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./external/IAggregatorV3.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract strETHCustomAaveOracle {
    strETHCustomAaveOracle public immutable fallbackOracle;

    constructor(address fallbackOracle_) {
        fallbackOracle = strETHCustomAaveOracle(fallbackOracle_);
    }

    function getAssetPrice(address asset) public view returns (uint256) {
        if (asset == address(0)) {
            return 1e8;
        }
        (address[] memory assets, address[][] memory aggregatedSources) =
            abi.decode(Clones.fetchCloneArgs(address(this)), (address[], address[][]));
        address[] memory sources;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                sources = aggregatedSources[i];
                break;
            }
        }
        if (sources.length == 0) {
            return fallbackOracle.getAssetPrice(asset);
        } else {
            int256 minPrice = type(int256).max;
            for (uint256 i = 0; i < sources.length; i++) {
                int256 price = IAggregatorV3(sources[i]).latestAnswer();
                if (price > 0 && price < minPrice) {
                    minPrice = price;
                }
            }
            if (minPrice < type(int256).max && minPrice > 0) {
                return uint256(minPrice);
            } else {
                return fallbackOracle.getAssetPrice(asset);
            }
        }
    }
}
