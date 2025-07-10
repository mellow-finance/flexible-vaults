// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract MockTokenizedShareManager is TokenizedShareManager {
    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    function mintShares(address account, uint256 value) external {
        _mint(account, value);
    }

    function test() external {}
}

contract TokenizedShareManagerTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;

    address[] assetsDefault;

    function setUp() external {
        for (uint256 index = 0; index < 3; index++) {
            assetsDefault.push(address(new MockERC20()));
        }
    }

    function testCreate() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        MockTokenizedShareManager shareManager = MockTokenizedShareManager(address(deployment.shareManager));
        assertEq(shareManager.activeSharesOf(user), 0, "Initial shares should be zero");
        assertEq(shareManager.activeShares(), 0, "Initial shares should be zero");
        shareManager.mintShares(user, 1 ether);
        assertEq(shareManager.activeSharesOf(user), 1 ether, "Shares should not be zero");
        assertEq(shareManager.activeShares(), 1 ether, "Active shares should not be zero");
    }

    function createShareManager(Deployment memory deployment)
        internal
        override
        returns (ShareManager shareManager, ShareManager shareManagerImplementation)
    {
        shareManagerImplementation = new MockTokenizedShareManager("Mellow", 1);
        shareManager = MockTokenizedShareManager(
            address(
                new TransparentUpgradeableProxy(
                    address(shareManagerImplementation), deployment.vaultProxyAdmin, new bytes(0)
                )
            )
        );
        vm.startPrank(deployment.vaultAdmin);
        {
            shareManager.initialize(abi.encode(bytes32(0), string("VaultERC20Name"), string("VaultERC20Symbol")));
            shareManager.setVault(address(deployment.vault));
        }
        vm.stopPrank();
    }
}
