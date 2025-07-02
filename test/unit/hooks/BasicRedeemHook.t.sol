// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract BasicRedeemHookTest is Test {
    MockERC20 asset1 = new MockERC20();
    MockERC20 asset2 = new MockERC20();
    MockVault vault = new MockVault();
    address subvault1 = vm.createWallet("subvault1").addr;
    address subvault2 = vm.createWallet("subvault2").addr;

    function testGetLiquidAssets() external {
        asset1.mint(address(vault), 11 ether);
        asset2.mint(address(vault), 22 ether);

        vault.addSubvault(subvault1, asset1, 1 ether);
        vault.addSubvault(subvault2, asset2, 2 ether);

        vm.prank(address(vault));
        assertEq(vault.getLiquidAssetsCall(address(asset1)), 12 ether);

        vm.prank(address(vault));
        assertEq(vault.getLiquidAssetsCall(address(asset2)), 24 ether);
    }

    function testBeforeRedeem() external {
        uint256 vaultBalance1 = 11 ether;
        uint256 vaultBalance2 = 22 ether;
        uint256 subvaultBalance1 = 1 ether;
        uint256 subvaultBalance2 = 2 ether;
        asset1.mint(address(vault), vaultBalance1);
        asset2.mint(address(vault), vaultBalance2);

        vault.addSubvault(subvault1, asset1, subvaultBalance1);
        vault.addSubvault(subvault2, asset2, subvaultBalance2);

        /// @dev no side effects, because balance of vault > assets
        vault.beforeRedeemHookCall(address(asset1), vaultBalance1 / 10);
        vault.beforeRedeemHookCall(address(asset2), vaultBalance2 / 10);
        require(vaultBalance1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(vaultBalance2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(subvaultBalance1 == IERC20(address(asset1)).balanceOf(address(subvault1)));
        require(subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(subvault2)));

        uint256 redeemAssets1 = 0.5 ether;
        vault.beforeRedeemHookCall(address(asset1), vaultBalance1 + redeemAssets1);
        require(vaultBalance1 + redeemAssets1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(subvaultBalance1 - redeemAssets1 == IERC20(address(asset1)).balanceOf(address(subvault1)));
        require(subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(subvault2)));

        uint256 redeemAssets2 = 0.8 ether;
        vault.beforeRedeemHookCall(address(asset2), vaultBalance2 + redeemAssets2);
        require(vaultBalance2 + redeemAssets2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(subvaultBalance2 - redeemAssets2 == IERC20(address(asset2)).balanceOf(address(subvault2)));
        require(subvaultBalance1 - redeemAssets1 == IERC20(address(asset1)).balanceOf(address(subvault1)));

        vault.beforeRedeemHookCall(address(asset1), 1000 ether);
        require(vaultBalance1 + subvaultBalance1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(0 == IERC20(address(asset1)).balanceOf(address(subvault1)));

        vault.beforeRedeemHookCall(address(asset2), 1000 ether);
        require(vaultBalance2 + subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(0 == IERC20(address(asset2)).balanceOf(address(subvault2)));
    }
}
