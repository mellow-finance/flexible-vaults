// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockVault is BasicRedeemHook {
    address[] internal subvault;

    function addSubvault(address subvault_, MockERC20 asset_, uint256 amount_) external {
        subvault.push(subvault_);
        asset_.mint(subvault_, amount_);
    }

    function subvaults() external view returns (uint256) {
        return subvault.length;
    }

    function subvaultAt(uint256 index) external view returns (address) {
        return subvault[index];
    }

    function pullAssets(address subvault, address asset, uint256 value) external {
        MockERC20(asset).take(subvault, value);
    }

    function test() external {}
}

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
        assertEq(vault.getLiquidAssets(address(asset1)), 12 ether);

        vm.prank(address(vault));
        assertEq(vault.getLiquidAssets(address(asset2)), 24 ether);
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
        vault.beforeRedeem(address(asset1), vaultBalance1 / 10);
        vault.beforeRedeem(address(asset2), vaultBalance2 / 10);
        require(vaultBalance1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(vaultBalance2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(subvaultBalance1 == IERC20(address(asset1)).balanceOf(address(subvault1)));
        require(subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(subvault2)));

        uint256 redeemAssets1 = 0.5 ether;
        vault.beforeRedeem(address(asset1), vaultBalance1 + redeemAssets1);
        require(vaultBalance1 + redeemAssets1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(subvaultBalance1 - redeemAssets1 == IERC20(address(asset1)).balanceOf(address(subvault1)));
        require(subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(subvault2)));

        uint256 redeemAssets2 = 0.8 ether;
        vault.beforeRedeem(address(asset2), vaultBalance2 + redeemAssets2);
        require(vaultBalance2 + redeemAssets2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(subvaultBalance2 - redeemAssets2 == IERC20(address(asset2)).balanceOf(address(subvault2)));
        require(subvaultBalance1 - redeemAssets1 == IERC20(address(asset1)).balanceOf(address(subvault1)));

        vault.beforeRedeem(address(asset1), 1000 ether);
        require(vaultBalance1 + subvaultBalance1 == IERC20(address(asset1)).balanceOf(address(vault)));
        require(0 == IERC20(address(asset1)).balanceOf(address(subvault1)));

        vault.beforeRedeem(address(asset2), 1000 ether);
        require(vaultBalance2 + subvaultBalance2 == IERC20(address(asset2)).balanceOf(address(vault)));
        require(0 == IERC20(address(asset2)).balanceOf(address(subvault2)));
    }
}
