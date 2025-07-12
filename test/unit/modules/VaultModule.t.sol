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

contract VaultModuleTest is FixtureTest {
    address vaultAdmin = vm.createWallet("vaultAdmin").addr;
    address vaultProxyAdmin = vm.createWallet("vaultProxyAdmin").addr;
    address user = vm.createWallet("user").addr;

    address[] assets;

    function setUp() external {
        assets.push(address(new MockERC20()));
    }

    function testCreateSubvault() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        Factory newVerifierFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), vaultProxyAdmin, new bytes(0)
                )
            )
        );
        newVerifierFactory.initialize(abi.encode(vaultAdmin));

        vm.startPrank(vaultAdmin);
        address verifierImplementation = address(new Verifier("Mellow", 1));
        newVerifierFactory.proposeImplementation(verifierImplementation);
        newVerifierFactory.acceptProposedImplementation(verifierImplementation);
        Verifier newVerifier =
            Verifier(newVerifierFactory.create(0, vaultProxyAdmin, abi.encode(address(deployment.vault), bytes32(0))));
        Factory anotherVerifierFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment.factoryImplementation), vaultProxyAdmin, new bytes(0)
                )
            )
        );
        anotherVerifierFactory.initialize(abi.encode(vaultAdmin));

        vm.expectRevert(abi.encodeWithSelector(IVaultModule.NotEntity.selector, address(newVerifier)));
        deployment.vault.createSubvault(0, vaultProxyAdmin, address(newVerifier));

        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));

        require(subvault != address(0), "subvault creation failed");
        assertTrue(deployment.vault.subvaults() == 1, "subvault length mismatch");
        assertEq(deployment.vault.subvaultAt(0), subvault, "subvault address mismatch");
        assertTrue(deployment.vault.hasSubvault(subvault), "wrong subvault address");
        vm.stopPrank();
    }

    function testDisconnectSubvault() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);

        vm.startPrank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));

        deployment.vault.disconnectSubvault(subvault);
        assertTrue(deployment.vault.subvaults() == 0, "subvault not disconnected");
        assertFalse(deployment.vault.hasSubvault(subvault), "subvault not disconnected");

        vm.expectRevert(abi.encodeWithSelector(IVaultModule.NotConnected.selector, subvault));
        deployment.vault.disconnectSubvault(subvault);
        vm.stopPrank();
    }

    function testReconnectSubvault() external {
        Deployment memory deployment1 = createVault(vaultAdmin, vaultProxyAdmin, assets);
        address invalidVault = vm.createWallet("invalidVault").addr;

        vm.prank(vaultAdmin);
        address subvault1 = deployment1.vault.createSubvault(0, vaultProxyAdmin, address(deployment1.verifier));
        address subvaultSide = deployment1.subvaultFactory.create(
            0, vaultProxyAdmin, abi.encode(deployment1.verifier, address(invalidVault))
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert(abi.encodeWithSelector(IVaultModule.AlreadyConnected.selector, subvault1));
        deployment1.vault.reconnectSubvault(subvault1);

        deployment1.vault.disconnectSubvault(subvault1);
        assertTrue(deployment1.vault.subvaults() == 0, "subvault not disconnected");
        assertFalse(deployment1.vault.hasSubvault(subvault1), "subvault not disconnected");
        deployment1.vault.reconnectSubvault(subvault1);
        assertTrue(deployment1.vault.subvaults() == 1, "subvault not reconnected");
        assertTrue(deployment1.vault.hasSubvault(subvault1), "subvault not reconnected");

        Factory newVerifierFactory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(deployment1.factoryImplementation), vaultProxyAdmin, new bytes(0)
                )
            )
        );
        newVerifierFactory.initialize(abi.encode(vaultAdmin));

        address verifierImplementation = address(new Verifier("Mellow", 1));
        newVerifierFactory.proposeImplementation(verifierImplementation);
        newVerifierFactory.acceptProposedImplementation(verifierImplementation);
        Verifier newVerifier =
            Verifier(newVerifierFactory.create(0, vaultProxyAdmin, abi.encode(address(deployment1.vault), bytes32(0))));

        address subvaultSide2 = deployment1.vault.subvaultFactory().create(
            0, vaultProxyAdmin, abi.encode(newVerifier, address(deployment1.vault))
        );
        vm.expectRevert(abi.encodeWithSelector(IVaultModule.NotEntity.selector, address(newVerifier)));
        deployment1.vault.reconnectSubvault(subvaultSide2);

        newVerifier = Verifier(
            deployment1.verifierFactory.create(0, vaultProxyAdmin, abi.encode(address(invalidVault), bytes32(0)))
        );
        subvaultSide2 = deployment1.vault.subvaultFactory().create(
            0, vaultProxyAdmin, abi.encode(newVerifier, address(deployment1.vault))
        );
        vm.expectRevert(abi.encode(IACLModule.Forbidden.selector));
        deployment1.vault.reconnectSubvault(subvaultSide2);
        vm.stopPrank();

        Deployment memory deployment2 = createVault(vaultAdmin, vaultProxyAdmin, assets);
        vm.prank(vaultAdmin);
        address subvault2 = deployment2.vault.createSubvault(0, vaultProxyAdmin, address(deployment2.verifier));

        vm.startPrank(vaultAdmin);
        deployment1.vault.disconnectSubvault(subvault1);
        deployment2.vault.disconnectSubvault(subvault2);
        assertTrue(deployment1.vault.subvaults() == 0, "subvault not disconnected");
        assertFalse(deployment1.vault.hasSubvault(subvault1), "subvault not disconnected");
        assertTrue(deployment2.vault.subvaults() == 0, "subvault not disconnected");
        assertFalse(deployment2.vault.hasSubvault(subvault2), "subvault not disconnected");

        vm.expectRevert(abi.encodeWithSelector(IVaultModule.NotEntity.selector, address(subvault2)));
        deployment1.vault.reconnectSubvault(subvault2);

        vm.expectRevert(abi.encodeWithSelector(IVaultModule.InvalidSubvault.selector, address(subvaultSide)));
        deployment1.vault.reconnectSubvault(subvaultSide);

        vm.stopPrank();
    }

    function testPushAndPullAssets() external {
        Deployment memory deployment = createVault(vaultAdmin, vaultProxyAdmin, assets);
        address asset = deployment.assets[0];

        vm.startPrank(vaultAdmin);
        address subvault = deployment.vault.createSubvault(0, vaultProxyAdmin, address(deployment.verifier));

        deployment.riskManager.allowSubvaultAssets(subvault, deployment.assets);

        vm.warp(block.timestamp + 10);

        MockERC20(asset).mint(address(deployment.vault), 1 ether);
        IOracle.Report[] memory reports = new IOracle.Report[](1);
        reports[0] = IOracle.Report({asset: asset, priceD18: 1e6});
        deployment.oracle.submitReports(reports);
        deployment.oracle.acceptReport(asset, 1e6, uint32(block.timestamp));

        deployment.riskManager.setSubvaultLimit(subvault, int256(1 ether));
        assertEq(MockERC20(asset).balanceOf(address(deployment.vault)), 1 ether, "Vault should have 1 ether of asset");
        deployment.vault.pushAssets(subvault, address(asset), 1 ether);
        assertEq(MockERC20(asset).balanceOf(address(deployment.vault)), 0, "Vault should not have assets");
        assertEq(MockERC20(asset).balanceOf(address(subvault)), 1 ether, "Subvault should have 1 ether of asset");
        deployment.vault.pullAssets(subvault, address(asset), 1 ether);
        assertEq(MockERC20(asset).balanceOf(address(deployment.vault)), 1 ether, "Vault should have 1 ether of asset");
        vm.stopPrank();
    }
}
