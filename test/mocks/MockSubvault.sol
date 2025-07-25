// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";

contract MockSubvault {
    constructor() {}

    function sendValue(address to, uint256 value) external {
        Address.sendValue(payable(to), value);
    }

    function test() external {}
}
