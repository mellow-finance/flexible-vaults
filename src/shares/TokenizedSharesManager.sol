// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./SharesManager.sol";

contract TokenizedSharesManager is SharesManager, ERC20Upgradeable {
    using SharesManagerFlagLibrary for uint256;

    // View functions

    function activeSharesOf(address account) public view override returns (uint256) {
        return balanceOf(account);
    }

    function activeShares() public view override returns (uint256) {
        return totalSupply();
    }

    // Internal functions

    function _mintShares(address account, uint256 value) internal override {
        _mint(account, value);
    }

    function _burnShares(address account, uint256 value) internal override {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        updateChecks(from, to, value);
        super._update(from, to, value);
    }
}
