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

        vault.lidoDepositHookCall(TransferLibrary.ETH, 1 ether);

        vault.lidoDepositHookCall(WETH, 1 ether);

        vault.lidoDepositHookCall(stETH, 1 ether);

        vault.lidoDepositHookCall(wstETH, 1 ether);
    }

    function testAfterDepositNextHook() external {
        vault.addLidoDepositHook(vault.redirectingDepositHook());

        vault.addRiskManager(0 ether);
        address wstETH = vault.wstETH();

        deal(wstETH, address(vault), 10 ether);

        vault.lidoDepositHookCall(wstETH, 1 ether);
    }
}
