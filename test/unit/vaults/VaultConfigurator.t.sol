// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract VaultConfiguratorTest is Test {
    VaultConfigurator internal configurator;

    address internal proxyAdmin = makeAddr("proxyAdmin");
    address internal vaultAdmin = makeAddr("vaultAdmin");

    address internal shareManagerFactory;
    address internal feeManagerFactory;
    address internal riskManagerFactory;
    address internal oracleFactory;
    address internal vaultFactory;

    function setUp() external {
        shareManagerFactory = _createShareManagerFactory();
        feeManagerFactory = _createFeeManagerFactory();
        riskManagerFactory = _createRiskManagerFactory();
        oracleFactory = _createOracleFactory();
        vaultFactory = _createVaultFactory();

        configurator = new VaultConfigurator(
            shareManagerFactory, feeManagerFactory, riskManagerFactory, oracleFactory, vaultFactory
        );
    }

    /**
     * Constructor tests
     */

    /// @notice Tests that the constructor correctly sets all factory addresses as immutable state variables.
    function testConstructorSetsFactoryAddresses() external view {
        assertEq(address(configurator.shareManagerFactory()), shareManagerFactory);
        assertEq(address(configurator.feeManagerFactory()), feeManagerFactory);
        assertEq(address(configurator.riskManagerFactory()), riskManagerFactory);
        assertEq(address(configurator.oracleFactory()), oracleFactory);
        assertEq(address(configurator.vaultFactory()), vaultFactory);
    }

    /**
     * Create function tests
     */

    /// @notice Tests that create() successfully creates all components.
    function testCreateSuccessfullyCreatesAllComponents() external {
        (address shareManager, address feeManager, address riskManager, address oracle, address vault) =
            configurator.create(_createValidInitParams());
        assertEq(Factory(shareManagerFactory).isEntity(shareManager), true);
        assertEq(Factory(feeManagerFactory).isEntity(feeManager), true);
        assertEq(Factory(riskManagerFactory).isEntity(riskManager), true);
        assertEq(Factory(oracleFactory).isEntity(oracle), true);

        assertEq(Factory(vaultFactory).isEntity(vault), true);
    }

    /// @notice Tests that create() correctly sets vault relationships between components.
    function testCreateSetsVaultRelationships() external {
        (address shareManager,, address riskManager, address oracle, address vault) =
            configurator.create(_createValidInitParams());
        assertEq(IShareManager(shareManager).vault(), vault);
        assertEq(IRiskManager(riskManager).vault(), vault);
        assertEq(address(IOracle(oracle).vault()), vault);
    }

    /**
     * Helper functions
     */
    function _createFactory(address implementation) internal returns (address) {
        Factory factory = Factory(
            address(
                new TransparentUpgradeableProxy(
                    address(new Factory("Mellow", 1)),
                    proxyAdmin,
                    abi.encodeWithSelector(Factory.initialize.selector, abi.encode(vaultAdmin))
                )
            )
        );

        factory.proposeImplementation(address(implementation));
        vm.prank(vaultAdmin);
        factory.acceptProposedImplementation(address(implementation));

        return address(factory);
    }

    function _createShareManagerFactory() internal returns (address) {
        BasicShareManager implementation = new BasicShareManager("BasicShareManager", 1);
        return _createFactory(address(implementation));
    }

    function _createFeeManagerFactory() internal returns (address) {
        FeeManager implementation = new FeeManager("FeeManager", 1);
        return _createFactory(address(implementation));
    }

    function _createRiskManagerFactory() internal returns (address) {
        RiskManager implementation = new RiskManager("RiskManager", 1);
        return _createFactory(address(implementation));
    }

    function _createOracleFactory() internal returns (address) {
        Oracle implementation = new Oracle("Oracle", 1);
        return _createFactory(address(implementation));
    }

    function _createVaultFactory() internal returns (address) {
        Vault implementation = new Vault(
            "Vault",
            1,
            makeAddr("depositQueueFactory"),
            makeAddr("redeemQueueFactory"),
            makeAddr("subvaultFactory"),
            makeAddr("verifierFactory")
        );
        return _createFactory(address(implementation));
    }

    /// @notice Creates a valid InitParams struct for testing.
    function _createValidInitParams() internal view returns (VaultConfigurator.InitParams memory) {
        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](0);

        return VaultConfigurator.InitParams({
            version: 0,
            proxyAdmin: proxyAdmin,
            vaultAdmin: vaultAdmin,
            shareManagerVersion: 0,
            shareManagerParams: abi.encode(bytes32(0)),
            feeManagerVersion: 0,
            feeManagerParams: abi.encode(vaultAdmin, vaultAdmin, 0, 1000, 0, 1000),
            riskManagerVersion: 0,
            riskManagerParams: abi.encode(int256(100 ether)),
            oracleVersion: 0,
            oracleParams: abi.encode(
                IOracle.SecurityParams({
                    maxAbsoluteDeviation: 0.05 ether,
                    suspiciousAbsoluteDeviation: 0.01 ether,
                    maxRelativeDeviationD18: 0.05 ether,
                    suspiciousRelativeDeviationD18: 0.01 ether,
                    timeout: 12 hours,
                    depositInterval: 1 hours,
                    redeemInterval: 1 hours
                }),
                new address[](0)
            ),
            defaultDepositHook: address(0),
            defaultRedeemHook: address(0),
            queueLimit: 10,
            roleHolders: roleHolders
        });
    }
}
