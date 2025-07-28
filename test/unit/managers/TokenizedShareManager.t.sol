// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract MockTokenizedShareManager is TokenizedShareManager {
    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    function mintShares(address account, uint256 value) external {
        _mint(account, value);
    }

    function __setIsClaiming(bool value) external {
        _tokenizedShareManagerStorage().isClaiming = value;
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

    /// @notice Tests that derived storage slot for the `TokenizedShareManager` is unique
    function testConstructorSetsUniqueStorageSlots() public {
        uint256 version = 1;
        string memory moduleName = "TokenizedShareManager";
        string memory name = "Mellow";

        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);
        MockTokenizedShareManager shareManager = MockTokenizedShareManager(address(deployment.shareManager));

        shareManager.__setIsClaiming(true);

        // Ensure the storage slot is set correctly
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, version);
            bool storedFlag = _loadBoolFromSlot(address(shareManager), moduleSlot);
            assertEq(storedFlag, true, "Flag value mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, name, 0);
            bool storedFlag = _loadBoolFromSlot(address(shareManager), moduleSlot);
            assertEq(storedFlag, false, "Flag should be unset for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 moduleSlot = SlotLibrary.getSlot(moduleName, "", version);
            bool storedFlag = _loadBoolFromSlot(address(shareManager), moduleSlot);
            assertEq(storedFlag, false, "Flag should be unset for different name");
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

    /// @notice Tests that the share manager should try to claim shares on transfer (or any other update)
    function testShouldClaimSharesOnTransfer() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assetsDefault);

        MockTokenizedShareManager shareManager = MockTokenizedShareManager(address(deployment.shareManager));

        address userA = vm.createWallet("userA").addr;
        address userB = vm.createWallet("userB").addr;

        shareManager.mintShares(userA, 1 ether);
        shareManager.mintShares(userB, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit IShareModule.SharesClaimed(userA);

        vm.expectEmit(true, true, true, true);
        emit IShareModule.SharesClaimed(userB);

        vm.prank(userA);
        shareManager.transfer(userB, 1 ether);
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

    /// @notice Loads a boolean value from a storage slot.
    function _loadBoolFromSlot(address _contract, bytes32 _slot) public view returns (bool) {
        bytes32 raw = vm.load(_contract, _slot);
        return uint256(raw) != 0;
    }
}
