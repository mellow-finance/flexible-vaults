// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/interfaces/factories/IFactoryEntity.sol";
import "../src/interfaces/modules/IShareModule.sol";
import "../src/managers/RecoveryShareManager.sol";
import "../src/managers/TokenizedShareManager.sol";

contract RecoveryTest is Test {
    // ERC-1967 admin slot: keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address shareManagerProxy = 0x8FB0EB4BB6CA5cf3883E83734BD5bD77a87CC20E;
    address tokenizedShareManagerImpl = 0x000000071F09E877c469749c093d09FB17896D6c;
    address recoveryShareManager = address(0);

    address mpcHolder = 0x8E234A6fE4ee15Ea4B15088B64af80Db26C8AE69;
    address recipient = makeAddr("recipient");

    address proxyAdminOwner = 0xb7b2ee53731Fc80080ED2906431e08452BC58786;

    function run() external {
        test_recovery();
    }

    function deploy_recovery_manager() internal {
        if (recoveryShareManager != address(0)) {
            return;
        }
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        recoveryShareManager = address(new RecoveryShareManager(mpcHolder, recipient));
        console2.log("RecoveryShareManager deployed at:", recoveryShareManager);
        vm.stopBroadcast();
    }

    function fetch_implementation() internal view returns (address) {
        return address(uint160(uint256(vm.load(address(shareManagerProxy), _IMPLEMENTATION_SLOT))));
    }

    function test_recovery() internal {
        // Retrieve the auto-created ProxyAdmin from the ERC-1967 admin slot
        ProxyAdmin proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(shareManagerProxy), _ADMIN_SLOT)))));
        assertEq(
            fetch_implementation(), tokenizedShareManagerImpl, "Initial implementation should be TokenizedShareManager"
        );

        // Cast proxy as TokenizedShareManager for convenience
        TokenizedShareManager shareManager = TokenizedShareManager(address(shareManagerProxy));

        uint256 mpcHolderShares = shareManager.balanceOf(mpcHolder);

        assertEq(shareManager.balanceOf(recipient), 0);

        // Step 0: deploy RecoveryShareManager with holder = mpcHolder, recipient = recipient
        deploy_recovery_manager();

        console2.log("MPC holder shares before recovery:", mpcHolderShares);

        // Step 1: upgrade to RecoveryShareManager and call recover() atomically
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(shareManagerProxy)),
            address(recoveryShareManager),
            abi.encodeCall(RecoveryShareManager.recover, ())
        );
        assertEq(
            fetch_implementation(),
            address(recoveryShareManager),
            "Implementation should be RecoveryShareManager after recovery"
        );

        // Shares are now in the recovery address
        assertEq(shareManager.balanceOf(mpcHolder), 0);
        assertEq(shareManager.balanceOf(recipient), mpcHolderShares);

        // Step 2: upgrade back to TokenizedShareManager (no init call needed — storage persists)
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(shareManagerProxy)), tokenizedShareManagerImpl, new bytes(0)
        );
        assertEq(
            fetch_implementation(),
            tokenizedShareManagerImpl,
            "Implementation should be TokenizedShareManager after upgrade back"
        );

        // Proxy is back to TokenizedShareManager; recovered shares are still in place
        assertEq(shareManager.balanceOf(recipient), mpcHolderShares);
        assertEq(shareManager.balanceOf(mpcHolder), 0);
        console2.log(" MPC holder shares after recovery:", shareManager.balanceOf(mpcHolder));
        console2.log("  Recipient shares after recovery:", shareManager.balanceOf(recipient));
    }
}
