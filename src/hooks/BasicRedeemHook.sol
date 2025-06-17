// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/hooks/IRedeemHook.sol";
import "../interfaces/modules/IRootVaultModule.sol";

contract BasicRedeemHook is IRedeemHook {
    function beforeRedeem(address asset, uint256 assets) public virtual {
        uint256 liquid = IERC20(asset).balanceOf(address(this));
        if (liquid >= assets) {
            return;
        }
        uint256 required = assets - liquid;
        IRootVaultModule vault = IRootVaultModule(address(this));
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            uint256 balance = IERC20(asset).balanceOf(subvault);
            if (balance == 0) {
                continue;
            }
            if (balance >= required) {
                IRootVaultModule(address(this)).pullAssets(subvault, asset, required);
                break;
            } else {
                IRootVaultModule(address(this)).pullAssets(subvault, asset, balance);
                required -= balance;
            }
        }
    }

    function getLiquidAssets(address asset) public view virtual returns (uint256 assets) {
        assets = IERC20(asset).balanceOf(address(this));
        IRootVaultModule vault = IRootVaultModule(address(this));
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            assets += IERC20(asset).balanceOf(subvault);
        }
    }
}
