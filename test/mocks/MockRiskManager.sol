// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract MockRiskManager {
    uint256 internal _limit;

    constructor(uint256 limit) {
        _limit = limit;
    }

    function maxDeposit(address, address) external view returns (uint256) {
        return _limit;
    }

    function test() external {}
}
