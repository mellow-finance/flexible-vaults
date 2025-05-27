// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";

contract StakingHook {
    address public immutable wstETH;
    address private immutable this_;

    constructor(address wstETH_) {
        require(wstETH_ != address(0), "wstETH address cannot be zero");
        wstETH = wstETH_;
        this_ = address(this);
    }

    function stake() public payable {
        if (address(this) == this_) {
            revert("StakingHook: only delegate call allowed");
        }
        // delegate call only
        Address.sendValue(payable(wstETH), msg.value);
    }
}
