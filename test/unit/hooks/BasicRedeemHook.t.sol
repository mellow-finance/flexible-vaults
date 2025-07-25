// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract BasicRedeemHookTest is Test {
    MockERC20 asset1 = new MockERC20();
    MockERC20 asset2 = new MockERC20();
    MockVault vault = new MockVault();
    address subvault1 = address(new MockSubvault());
    address subvault2 = address(new MockSubvault());

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

    function testGetLiquidAssets_WithNativeToken() external {
        address nativeToken = TransferLibrary.ETH;

        vm.deal(address(vault), 11 ether);

        vault.addSubvault(subvault1);
        vm.deal(subvault1, 1 ether);

        vault.addSubvault(subvault2);
        vm.deal(subvault2, 2.5 ether);

        vm.prank(address(vault));
        assertEq(vault.getLiquidAssetsCall(nativeToken), 14.5 ether);
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

    function testBeforeRedeem_WithNativeToken() external {
        address nativeToken = TransferLibrary.ETH;

        // Total is 30 ether
        uint256 vaultBalance = 10 ether;
        uint256 subvaultBalance1 = 10 ether;
        uint256 subvaultBalance2 = 10 ether;

        vault.addSubvault(subvault1);
        vault.addSubvault(subvault2);

        vm.deal(address(vault), vaultBalance);
        vm.deal(subvault1, subvaultBalance1);
        vm.deal(subvault2, subvaultBalance2);

        // Try to redeem 25 ether
        uint256 amountToRedeem = 25 ether;
        vault.beforeRedeemHookCall(nativeToken, amountToRedeem);

        // Vault should have 25 ether, it took full amount from subvault1 and 5 ether from subvault2
        require(address(vault).balance == 25 ether, "wrong vault balance");
        require(subvault1.balance == 0, "wrong subvault1 balance");
        require(subvault2.balance == 5 ether, "wrong subvault2 balance");
    }
}
