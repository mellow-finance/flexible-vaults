// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {TokenizedShareManager} from "./TokenizedShareManager.sol";

contract BurnableTokenizedShareManager is TokenizedShareManager {
    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}
