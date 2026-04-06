// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract RecoveryShareManager is ERC20Upgradeable {
    address public immutable holder;
    address public immutable recipient;

    constructor(address holder_, address recipient_) {
        holder = holder_;
        recipient = recipient_;
    }

    function recover() external {
        _transfer(holder, recipient, balanceOf(holder));
    }
}
