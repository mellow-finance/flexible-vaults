// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./TokenizedShareManager.sol";

contract RecoveryShareManager is TokenizedShareManager {
    address public immutable holder;
    address public immutable recipient;

    constructor(address holder_, address recipient_) TokenizedShareManager("Mellow", 1) {
        holder = holder_;
        recipient = recipient_;
    }

    function recover() external {
        _transfer(holder, recipient, sharesOf(holder));
    }
}
