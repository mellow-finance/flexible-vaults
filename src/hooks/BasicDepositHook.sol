// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/hooks/IDepositHook.sol";
import "../interfaces/modules/IDepositModule.sol";

import "../interfaces/modules/IRootVaultModule.sol";
import "../interfaces/modules/ISharesModule.sol";

contract BasicDepositHook is IDepositHook {
    function afterDeposit(address vault, address asset, uint256 assets) public virtual {
        address depositQueue = msg.sender;
        require(IDepositModule(vault).hasDepositQueue(depositQueue), "BasicDepositHook: not a deposit queue");
        IRiskManager riskManager = IRootVaultModule(vault).riskManager();
        uint256 subvaults = IRootVaultModule(vault).subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = IRootVaultModule(vault).subvaultAt(i);
            uint256 assets_ = riskManager.maxDeposit(subvault, asset);
            if (assets_ == 0) {
                continue;
            }
            if (assets_ < assets) {
                IRootVaultModule(vault).pushAssets(subvault, asset, assets_);
                assets -= assets_;
            } else {
                IRootVaultModule(vault).pushAssets(subvault, asset, assets);
                break;
            }
        }
    }
}
