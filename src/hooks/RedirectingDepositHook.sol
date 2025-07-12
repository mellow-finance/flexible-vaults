// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/hooks/IHook.sol";
import "../interfaces/modules/IVaultModule.sol";

contract RedirectingDepositHook is IHook {
    function callHook(address asset, uint256 assets) public virtual {
        IVaultModule vault = IVaultModule(address(this));
        IRiskManager riskManager = vault.riskManager();
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            uint256 assets_ = riskManager.maxDeposit(subvault, asset);
            if (assets_ == 0) {
                continue;
            }
            if (assets_ < assets) {
                vault.hookPushAssets(subvault, asset, assets_);
                assets -= assets_;
            } else {
                vault.hookPushAssets(subvault, asset, assets);
                break;
            }
        }
    }
}
