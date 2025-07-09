// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract LidoDepositHookTest is Test {
    MockVault vault;
    address subvault = vm.createWallet("subvault").addr;
    address deployer = vm.createWallet("vault-deployer").addr;

    function setUp() external {
        vm.prank(deployer);
        vault = new MockVault();
    }

    function testAfterDeposit() external {
        vault.addLidoDepositHook(address(0));
        address WETH = vault.WETH();
        address stETH = IWSTETH(vault.wstETH()).stETH();
        address wstETH = vault.wstETH();

        address invalidAsset = vm.createWallet("invalidAsset").addr;
        vm.expectRevert(abi.encodeWithSelector(LidoDepositHook.UnsupportedAsset.selector, invalidAsset));
        vault.lidoDepositHookCall(invalidAsset, 1 ether);

        vm.deal(address(vault), 10 ether);
        deal(WETH, address(vault), 10 ether);
        deal(wstETH, address(vault), 10 ether);

        vm.prank(address(vault));
        IWSTETH(wstETH).unwrap(5 ether);

        uint256 ethBalanceBefore = address(vault).balance;
        vault.lidoDepositHookCall(TransferLibrary.ETH, 1 ether);
        require(address(vault).balance == ethBalanceBefore - 1 ether, "ETH balance should decrease by 1 ether");

        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(vault));
        vault.lidoDepositHookCall(WETH, 1 ether);
        require(
            IERC20(WETH).balanceOf(address(vault)) == wethBalanceBefore - 1 ether,
            "WETH balance should decrease by 1 ether"
        );

        uint256 stETHBalanceBefore = IERC20(stETH).balanceOf(address(vault));
        vault.lidoDepositHookCall(stETH, 1 ether);
        require(
            IERC20(stETH).balanceOf(address(vault)) == stETHBalanceBefore - 1 ether,
            "stETH balance should decrease by 1 ether"
        );

        uint256 wstETHBalanceBefore = IERC20(wstETH).balanceOf(address(vault));
        vault.lidoDepositHookCall(wstETH, 1 ether);
        // do not change because the hook is disabled
        require(IERC20(wstETH).balanceOf(address(vault)) == wstETHBalanceBefore, "wstETH balance should not change");
    }

    function testAfterDepositNextHook() external {
        vault.addLidoDepositHook(vault.redirectingDepositHook());
        vault.addSubvault(subvault, MockERC20(vault.wstETH()), 0 ether);

        vault.addRiskManager(1 ether);
        address wstETH = vault.wstETH();

        deal(wstETH, address(vault), 10 ether);

        uint256 wstETHBalanceBefore = IERC20(wstETH).balanceOf(address(vault));
        vault.lidoDepositHookCall(wstETH, 1 ether);
        require(
            IERC20(wstETH).balanceOf(address(vault)) == wstETHBalanceBefore - 1 ether,
            "wstETH balance should decrease by 1 ether"
        );
    }
}
