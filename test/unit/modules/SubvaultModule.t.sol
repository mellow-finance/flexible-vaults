// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract MockSubvaultModule is SubvaultModule {
    constructor(string memory name_, uint256 version_) SubvaultModule(name_, version_) {}

    function initialize(bytes calldata initParams) external initializer {
        (address vault_) = abi.decode(initParams, (address));
        __SubvaultModule_init(vault_);
    }

    function test() external {}
}

contract SubvaultModuleTest is Test {
    address admin = vm.createWallet("admin").addr;
    address proxyAdmin = vm.createWallet("proxyAdmin").addr;

    MockERC20 asset = new MockERC20();
    MockVault vault = new MockVault();
    address subvault = vm.createWallet("subvault").addr;

    function testCreate() external {
        MockSubvaultModule module = createSubvaultModule(address(vault));

        assertEq(module.vault(), address(vault), "Vault should match");
    }

    function testPullAssets() external {
        vault.addRiskManager(1 ether);
        vault.addSubvault(subvault, asset, 0 ether);
        MockSubvaultModule module = createSubvaultModule(address(vault));
        asset.mint(address(module), 1 ether);

        vm.expectRevert("NotVault()");
        module.pullAssets(address(asset), 1 ether);

        vm.prank(address(vault));
        module.pullAssets(address(asset), 1 ether);

        require(IERC20(address(asset)).balanceOf(address(vault)) == 1 ether, "Vault should have 1 ether of asset");
    }

    function createSubvaultModule(address vault_) internal returns (MockSubvaultModule module) {
        MockSubvaultModule moduleImplementation = new MockSubvaultModule("SubvaultModule", 1);
        module = MockSubvaultModule(
            payable(new TransparentUpgradeableProxy(address(moduleImplementation), proxyAdmin, new bytes(0)))
        );
        module.initialize(abi.encode(vault_));
    }
}
