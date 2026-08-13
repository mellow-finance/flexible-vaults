// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";

/// @notice RBTC is the base asset on Rootstock — its price relative to itself is always 1.
contract RootstockBTCOracle is ICustomPriceOracle {
    function priceX96() external pure returns (uint256) {
        return 2 ** 96;
    }
}
