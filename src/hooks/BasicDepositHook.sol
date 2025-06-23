// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/hooks/IDepositHook.sol";
import "../interfaces/modules/IShareModule.sol";
import "../interfaces/modules/IVaultModule.sol";

contract BasicDepositHook is IDepositHook {
    address private immutable _this;

    constructor() {
        _this = address(this);
    }

    function afterDeposit(address asset, uint256 assets) public virtual {
        IVaultModule vault = IVaultModule(address(this));
        if (address(vault) == _this) {
            revert("BasicDepositHook: delegate call only");
        }
        IRiskManager riskManager = vault.riskManager();
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            uint256 assets_ = riskManager.maxDeposit(subvault, asset);
            if (assets_ == 0) {
                continue;
            }
            if (assets_ < assets) {
                vault.pushAssets(subvault, asset, assets_);
                assets -= assets_;
            } else {
                vault.pushAssets(subvault, asset, assets);
                break;
            }
        }
    }
}
