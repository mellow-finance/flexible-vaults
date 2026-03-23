// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";

/// @notice BTC is the base asset on Mezo — its price relative to itself is always 1.
contract MezoBTCOracle is ICustomPriceOracle {
    function priceX96() external pure returns (uint256) {
        return 2 ** 96;
    }
}
