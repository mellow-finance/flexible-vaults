// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SharesManager.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract SharesManagerERC20 is SharesManager, ERC20Upgradeable {
    function activeSharesOf(address account) public view override returns (uint256) {
        return _ERC20Storage()._balances[account];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return sharesOf(account);
    }

    function mintShares(address to, uint256 shares) external override {
        if (to == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        unchecked {
            _ERC20Storage()._balances[to] += shares;
        }
        emit SharesMinted(to, shares);
        emit Transfer(address(0), to, shares);
    }

    function allocateShares(uint256 shares) external override {
        _ERC20Storage()._totalSupply += shares;
    }

    function mintAllocatedShares(address to, uint256 amount) external override {
        unchecked {
            _ERC20Storage()._balances[to] += amount;
        }
        emit SharesMinted(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function pullShares(address from, uint256 amount) external override {
        address caller = _msgSender();
        _transfer(from, caller, amount);
        emit Transfer(from, caller, amount);
    }

    function burnShares(address from, uint256 amount) external override {
        if (from == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        ERC20Storage storage $ = _ERC20Storage();
        $._balances[from] -= amount;
        unchecked {
            $._totalSupply -= amount;
        }
        emit SharesBurned(from, amount);
        emit Transfer(from, address(0), amount);
    }

    function _ERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            // ERC20 storage location
            $.slot := 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00
        }
    }
}
