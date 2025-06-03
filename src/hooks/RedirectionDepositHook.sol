// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/DepositQueue.sol";
import "./DepositHook.sol";

contract RedirectionDepositHook is DepositHook {
    address public immutable to;

    constructor(address to_) {
        if (to_ == address(0)) {
            revert("DefaultDepositHook: invalid destination address");
        }
        to = to_;
    }

    function hook(address asset, uint256 assets) external virtual override onlyDelegateCall {
        _pushAssets(asset, assets);
    }

    function _pushAssets(address asset, uint256 assets) internal {
        TransferLibrary.sendAssets(asset, to, assets);
    }
}
