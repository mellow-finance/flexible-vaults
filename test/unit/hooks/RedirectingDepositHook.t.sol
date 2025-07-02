// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract RedirectingDepositHookTest is Test {
    MockERC20 asset1 = new MockERC20();
    MockERC20 asset2 = new MockERC20();
    MockVault vault = new MockVault();
    address subvault1 = vm.createWallet("subvault1").addr;
    address subvault2 = vm.createWallet("subvault2").addr;

    function testPush() external {
        vault.addRiskManager(1 ether);

        asset1.mint(address(vault), 1 ether);
        asset2.mint(address(vault), 2 ether);

        vault.addSubvault(subvault1, asset1, 0 ether);

        vault.afterDepositHookCall(address(asset1), 1 ether);
        require(1 ether == IERC20(address(asset1)).balanceOf(address(subvault1)));
        vault.afterDepositHookCall(address(asset2), 1 ether);
        require(1 ether == IERC20(address(asset2)).balanceOf(address(subvault1)));

        vault.afterDepositHookCall(address(asset2), 2 ether);
        require(2 ether == IERC20(address(asset2)).balanceOf(address(subvault1)));
    }

    function testPushSkip() external {
        vault.addRiskManager(0 ether);

        asset1.mint(address(vault), 1 ether);
        asset2.mint(address(vault), 2 ether);

        vault.addSubvault(subvault1, asset1, 0 ether);

        vault.afterDepositHookCall(address(asset1), 1 ether);
        require(0 ether == IERC20(address(asset1)).balanceOf(address(subvault1)));
        vault.afterDepositHookCall(address(asset2), 1 ether);
        require(0 ether == IERC20(address(asset2)).balanceOf(address(subvault1)));

        vault.afterDepositHookCall(address(asset2), 2 ether);
        require(0 ether == IERC20(address(asset2)).balanceOf(address(subvault1)));
    }
}
