// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/DepositQueue.sol";
import "./DepositHook.sol";

contract DefaultDepositHook is DepositHook {
    function hook(address asset, uint256 assets) external virtual override onlyDelegateCall {
        _pushAssets(asset, assets);
    }

    function _pushAssets(address asset, uint256 assets) internal {
        address vault = address(DepositQueue(address(this)).vault());
        TransferLibrary.sendAssets(asset, vault, assets);
    }
}
