// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/hooks/IHook.sol";
import "../interfaces/modules/IVaultModule.sol";
import "../libraries/TransferLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BasicRedeemHook is IHook {
    using TransferLibrary for address;

    function callHook(address asset, uint256 assets) public virtual {
        IVaultModule vault = IVaultModule(address(this));
        uint256 liquid = asset.balanceOf(address(vault));
        if (liquid >= assets) {
            return;
        }
        uint256 requiredAssets = assets - liquid;
        uint256 subvaults = vault.subvaults();
        IRiskManager riskManager = vault.riskManager();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            if (!riskManager.isAllowedAsset(subvault, asset)) {
                continue;
            }
            uint256 balance = asset.balanceOf(subvault);
            if (balance == 0) {
                continue;
            }
            if (balance >= requiredAssets) {
                vault.hookPullAssets(subvault, asset, requiredAssets);
                break;
            } else {
                vault.hookPullAssets(subvault, asset, balance);
                requiredAssets -= balance;
            }
        }
    }

    function getLiquidAssets(address asset) public view virtual returns (uint256 assets) {
        IVaultModule vault = IVaultModule(msg.sender);
        assets = asset.balanceOf(address(vault));
        uint256 subvaults = vault.subvaults();
        IRiskManager riskManager = vault.riskManager();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            if (!riskManager.isAllowedAsset(subvault, asset)) {
                continue;
            }
            assets += asset.balanceOf(subvault);
        }
    }
}
