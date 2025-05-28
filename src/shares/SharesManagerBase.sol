// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SharesManager.sol";

contract SharesManagerBase is SharesManager {
    using SharesManagerFlagLibrary for uint256;

    // TODO:
    // 1. add permissions
    // 2. add deallocation && burnDeallocatedShares

    mapping(address => uint256) private _sharesOf;
    uint256 public totalShares;

    function activeSharesOf(address account) public view override returns (uint256) {
        return _sharesOf[account];
    }

    function mintShares(address to, uint256 amount) external override {
        if (flags.hasMintPause()) {
            revert("SharesManagerBase: minting is paused");
        }
        if (to == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        totalShares += amount;
        unchecked {
            _sharesOf[to] += amount;
        }
        emit SharesMinted(to, amount);
    }

    function allocateShares(uint256 amount) external override {
        if (flags.hasMintPause()) {
            revert("SharesManagerBase: minting is paused");
        }
        totalShares += amount;
    }

    function mintAllocatedShares(address to, uint256 amount) external override {
        if (flags.hasMintPause()) {
            revert("SharesManagerBase: minting is paused");
        }
        if (to == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        unchecked {
            _sharesOf[to] += amount;
        }
        emit SharesMinted(to, amount);
    }

    function pullShares(address from, uint256 amount) external override {
        if (flags.hasBurnPause()) {
            revert("SharesManagerBase: burning is paused");
        }
        if (from == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        if (_sharesOf[from] < amount) {
            revert("SharesManagerBase: insufficient shares");
        }
        unchecked {
            _sharesOf[from] -= amount;
        }
        totalShares -= amount;
    }

    function burnShares(address from, uint256 amount) external override {
        if (flags.hasBurnPause()) {
            revert("SharesManagerBase: burning is paused");
        }
        if (from == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        if (_sharesOf[from] < amount) {
            revert("SharesManagerBase: insufficient shares");
        }
        unchecked {
            _sharesOf[from] -= amount;
        }
        totalShares -= amount;
        emit SharesBurned(from, amount);
    }
}
