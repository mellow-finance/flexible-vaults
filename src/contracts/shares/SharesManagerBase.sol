// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SharesManager.sol";

contract SharesManagerBase is SharesManager {
    mapping(address => uint256) private _sharesOf;
    uint256 public totalShares;

    function activeSharesOf(address account) public view override returns (uint256) {
        return _sharesOf[account];
    }

    function mintShares(address to, uint256 amount) external override 
    // requireAuth(isDepositQueue[msg.sender])
    {
        if (to == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        totalShares += amount;
        unchecked {
            _sharesOf[to] += amount;
        }
        emit SharesMinted(to, amount);
    }

    function allocateShares(uint256 amount) external override 
    // requireAuth(isDepositQueue[msg.sender])
    {
        totalShares += amount;
    }

    function mintAllocatedShares(address to, uint256 amount) external override 
    // requireAuth(isDepositQueue[msg.sender])
    {
        if (to == address(0)) {
            revert("SharesManagerBase: zero address");
        }
        unchecked {
            _sharesOf[to] += amount;
        }
        emit SharesMinted(to, amount);
    }
}
