// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IAggregatorV3 {
    function latestAnswer() external view returns (int256);
}

contract BtcEthOracle is ICustomPriceOracle {
    address public constant aggregatorV3 = 0xdeb288F737066589598e9214E782fa5A8eD689e8; // BTC/ETH
    uint256 private decimals;

    constructor(uint256 decimals_) {
        decimals = decimals_;
    }

    function priceX96() external view returns (uint256) {
        uint256 priceD8 = uint256(IAggregatorV3(aggregatorV3).latestAnswer());
        return Math.mulDiv(uint256(priceD8), 2 ** 96, 10 ** decimals);
    }
}
