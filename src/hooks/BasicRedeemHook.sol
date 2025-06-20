// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/hooks/IRedeemHook.sol";
import "../interfaces/modules/IVaultModule.sol";

contract BasicRedeemHook is IRedeemHook {
    function beforeRedeem(address asset, uint256 assets) public virtual {
        IVaultModule vault = IVaultModule(msg.sender);
        uint256 liquid = IERC20(asset).balanceOf(address(vault));
        if (liquid >= assets) {
            return;
        }
        uint256 required = assets - liquid;
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            uint256 balance = IERC20(asset).balanceOf(subvault);
            if (balance == 0) {
                continue;
            }
            if (balance >= required) {
                vault.pullAssets(subvault, asset, required);
                break;
            } else {
                vault.pullAssets(subvault, asset, balance);
                required -= balance;
            }
        }
    }

    function getLiquidAssets(address asset) public view virtual returns (uint256 assets) {
        IVaultModule vault = IVaultModule(msg.sender);
        assets = IERC20(asset).balanceOf(address(vault));
        uint256 subvaults = vault.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = vault.subvaultAt(i);
            assets += IERC20(asset).balanceOf(subvault);
        }
    }
}
