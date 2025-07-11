// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract VaultTest is Test {
    address internal proxyAdmin = makeAddr("proxyAdmin");
    address internal vaultAdmin = makeAddr("vaultAdmin");

    address internal shareManager = makeAddr("shareManager");
    address internal feeManager = makeAddr("feeManager");
    address internal riskManager = makeAddr("riskManager");
    address internal oracle = makeAddr("oracle");
    address internal defaultDepositHook = makeAddr("defaultDepositHook");
    address internal defaultRedeemHook = makeAddr("defaultRedeemHook");
    address internal depositQueueFactory = makeAddr("depositQueueFactory");
    address internal redeemQueueFactory = makeAddr("redeemQueueFactory");
    address internal subvaultFactory = makeAddr("subvaultFactory");
    address internal verifierFactory = makeAddr("verifierFactory");

    uint256 internal constant queueLimit = 10;
    bytes32 internal constant ROLE_1 = keccak256("ROLE_1");
    bytes32 internal constant ROLE_2 = keccak256("ROLE_2");

    Vault internal vault;

    function setUp() public {
        vault = _createVault("Vault", 1);
    }

    /**
     * Constructor tests
     */

    /// @notice Tests that the constructor utilizes the name and version to set the unique storage slot for ACL module.
    function testConstructorSetsUniqueACLModuleSlot() public {
        uint256 version = 1;
        string memory name = "Vault";
        string memory moduleName = "MellowACL";

        vault = _createVault(name, version);

        // Ensure the vaultAdmin is stored correctly
        {
            bytes32 aclModuleSlot = SlotLibrary.getSlot(moduleName, name, version);
            uint256 rolesLength = uint256(vm.load(address(vault), aclModuleSlot));

            assertEq(rolesLength, 2, "Supported roles length should be 2");

            bytes32 adminRole = _loadBytes32FromSetSlot(address(vault), aclModuleSlot, 0);
            assertEq(adminRole, vault.DEFAULT_ADMIN_ROLE(), "First supported role should be default admin role");

            bytes32 holderRole = _loadBytes32FromSetSlot(address(vault), aclModuleSlot, 1);
            assertEq(holderRole, ROLE_1, "Second supported role should be ROLE_1");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 aclModuleSlot = SlotLibrary.getSlot(moduleName, name, version + 1);
            uint256 rolesLength = uint256(vm.load(address(vault), aclModuleSlot));
            assertEq(rolesLength, 0, "Supported roles should not be set for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 aclModuleSlot = SlotLibrary.getSlot(moduleName, "", version);
            uint256 rolesLength = uint256(vm.load(address(vault), aclModuleSlot));
            assertEq(rolesLength, 0, "Supported roles should not be set for different name");
        }
    }

    /// @notice Tests that the constructor utilizes the name and version to set the unique storage slot for Share module.
    function testConstructorSetsUniqueShareModuleSlot() public {
        uint256 version = 1;
        string memory name = "Vault";
        string memory moduleName = "ShareModule";

        vault = _createVault(name, version);

        // Ensure the shareManager is stored correctly
        {
            bytes32 shareModuleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedShareManager = _loadAddressFromSlot(address(vault), shareModuleSlot);
            assertEq(storedShareManager, shareManager, "ShareManager address mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 shareModuleSlot = SlotLibrary.getSlot(moduleName, name, version + 1);
            address storedShareManager = _loadAddressFromSlot(address(vault), shareModuleSlot);
            assertNotEq(storedShareManager, shareManager, "shareManager should not be set for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 shareModuleSlot = SlotLibrary.getSlot(moduleName, "", version);
            address storedShareManager = _loadAddressFromSlot(address(vault), shareModuleSlot);
            assertNotEq(storedShareManager, shareManager, "shareManager should not be set for different name");
        }
    }

    /// @notice Tests that the constructor utilizes the name and version to set the unique storage slot for Vault module.
    function testConstructorSetsUniqueVaultModuleSlot() public {
        uint256 version = 1;
        string memory name = "Vault";
        string memory moduleName = "VaultModule";

        vault = _createVault(name, version);

        // Ensure the riskManager is stored correctly
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedRiskManager = _loadAddressFromSlot(address(vault), vaultModuleSlot);
            assertEq(storedRiskManager, riskManager, "riskManager address mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, name, version + 1);
            address storedRiskManager = _loadAddressFromSlot(address(vault), vaultModuleSlot);
            assertNotEq(storedRiskManager, riskManager, "riskManager should not be set for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, "", version);
            address storedRiskManager = _loadAddressFromSlot(address(vault), vaultModuleSlot);
            assertNotEq(storedRiskManager, riskManager, "riskManager should not be set for different name");
        }
    }

    /// @notice Tests that the constructor sets the correct depositQueueFactory address.
    function testConstructorSetsDepositQueueFactory() public view {
        assertEq(address(vault.depositQueueFactory()), depositQueueFactory, "depositQueueFactory address mismatch");
    }

    /// @notice Tests that the constructor sets the correct redeemQueueFactory address.
    function testConstructorSetsRedeemQueueFactory() public view {
        assertEq(address(vault.redeemQueueFactory()), redeemQueueFactory, "redeemQueueFactory address mismatch");
    }

    /// @notice Tests that the constructor sets the correct subvaultFactory address.
    function testConstructorSetsSubvaultFactory() public view {
        assertEq(address(vault.subvaultFactory()), subvaultFactory, "subvaultFactory address mismatch");
    }

    /// @notice Tests that the constructor sets the correct verifierFactory address.
    function testConstructorSetsVerifierFactory() public view {
        assertEq(address(vault.verifierFactory()), verifierFactory, "verifierFactory address mismatch");
    }

    /**
     * Initialize function tests
     */

    /// @notice Tests that the initialize function correctly sets the admin.
    function testInitializeSetsAdmin() public view {
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), vaultAdmin), "admin role should be set");
    }

    /// @notice Tests that the initialize function correctly sets the shareManager.
    function testInitializeSetsShareManager() public view {
        assertEq(address(vault.shareManager()), shareManager, "shareManager address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the feeManager.
    function testInitializeSetsFeeManager() public view {
        assertEq(address(vault.feeManager()), feeManager, "feeManager address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the riskManager.
    function testInitializeSetsRiskManager() public view {
        assertEq(address(vault.riskManager()), riskManager, "riskManager address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the oracle.
    function testInitializeSetsOracle() public view {
        assertEq(address(vault.oracle()), oracle, "oracle address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the defaultDepositHook.
    function testInitializeSetsDefaultDepositHook() public view {
        assertEq(address(vault.defaultDepositHook()), defaultDepositHook, "defaultDepositHook address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the defaultRedeemHook.
    function testInitializeSetsDefaultRedeemHook() public view {
        assertEq(address(vault.defaultRedeemHook()), defaultRedeemHook, "defaultRedeemHook address mismatch");
    }

    /// @notice Tests that the initialize function correctly sets the queueLimit.
    function testInitializeSetsQueueLimit() public view {
        assertEq(vault.queueLimit(), queueLimit, "queueLimit mismatch");
    }

    /// @notice Tests that the initialize function correctly grants regular roles.
    function testInitializeGrantsRegularRoles() public {
        address holder1 = makeAddr("holder1");
        address holder2 = makeAddr("holder2");

        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](2);
        roleHolders[0] = _createRoleHolder(ROLE_1, holder1);
        roleHolders[1] = _createRoleHolder(ROLE_2, holder2);
        vault = _createVaultWithRoles("Vault", 1, roleHolders);

        assertTrue(vault.hasRole(ROLE_1, holder1), "role 1 should be set");
        assertTrue(vault.hasRole(ROLE_2, holder2), "role 2 should be set");
    }

    /// @notice Tests that the initialize function correctly handles empty role holders array.
    function testInitializeHandlesEmptyRoleHolders() public {
        _createVaultWithRoles("Vault", 1, new Vault.RoleHolder[](0)); // No revert expected
    }

    /// @notice Tests that the initialize function correctly handles same account with multiple roles.
    function testInitializeHandlesSameAccountMultipleRoles() public {
        address holder = makeAddr("holder");
        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](2);
        roleHolders[0] = _createRoleHolder(ROLE_1, holder);
        roleHolders[1] = _createRoleHolder(ROLE_2, holder);
        vault = _createVaultWithRoles("Vault", 1, roleHolders);

        assertTrue(vault.hasRole(ROLE_1, holder), "role 1 should be set");
        assertTrue(vault.hasRole(ROLE_2, holder), "role 2 should be set");
    }

    /// @notice Tests that the initialize function can only be called once.
    function testInitializeRevertsIfCalledTwice() public {
        vault = _createVaultWithRoles("Vault", 1, new Vault.RoleHolder[](0));
        vm.expectRevert();
        vault.initialize(
            abi.encode(
                vaultAdmin,
                shareManager,
                feeManager,
                riskManager,
                oracle,
                defaultDepositHook,
                defaultRedeemHook,
                queueLimit,
                new Vault.RoleHolder[](0)
            )
        );
    }

    /// @notice Tests that the initialize function emits Initialized event.
    function testInitializeEmitsInitializedEvent() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            shareManager,
            feeManager,
            riskManager,
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectEmit(true, true, true, true);
        emit IFactoryEntity.Initialized(initParams);

        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /**
     * Error handling tests
     */

    /// @notice Tests that the initialize function reverts with insufficient parameters.
    function testInitializeRevertsOnInsufficientParameters() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        // Missing role holders array
        bytes memory initParams = abi.encode(
            vaultAdmin, shareManager, feeManager, riskManager, oracle, defaultDepositHook, defaultRedeemHook, queueLimit
        );

        vm.expectRevert();
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with zero admin address.
    function testInitializeRevertsOnZeroAdminAddress() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            address(0),
            shareManager,
            feeManager,
            riskManager,
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectRevert(IACLModule.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with zero shareManager address.
    function testInitializeRevertsOnZeroShareManagerAddress() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            address(0),
            feeManager,
            riskManager,
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectRevert(IACLModule.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with zero feeManager address.
    function testInitializeRevertsOnZeroFeeManagerAddress() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            shareManager,
            address(0),
            riskManager,
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectRevert(IACLModule.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with zero riskManager address.
    function testInitializeRevertsOnZeroRiskManagerAddress() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            shareManager,
            feeManager,
            address(0),
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectRevert(IACLModule.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with zero oracle address.
    function testInitializeRevertsOnZeroOracleAddress() public {
        Vault vaultImplementation =
            new Vault("Vault", 1, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            shareManager,
            feeManager,
            riskManager,
            address(0),
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            new Vault.RoleHolder[](0)
        );

        vm.expectRevert(IACLModule.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
    }

    /**
     * Helper functions
     */
    function _createVault(string memory _name, uint256 _version) public returns (Vault) {
        Vault.RoleHolder[] memory roleHolders = new Vault.RoleHolder[](1);
        address someHolder = makeAddr("someHolder");
        roleHolders[0] = _createRoleHolder(ROLE_1, someHolder);
        return _createVaultWithRoles(_name, _version, roleHolders);
    }

    function _createVaultWithRoles(string memory _name, uint256 _version, Vault.RoleHolder[] memory _roleHolders)
        public
        returns (Vault)
    {
        Vault vaultImplementation =
            new Vault(_name, _version, depositQueueFactory, redeemQueueFactory, subvaultFactory, verifierFactory);

        bytes memory initParams = abi.encode(
            vaultAdmin,
            shareManager,
            feeManager,
            riskManager,
            oracle,
            defaultDepositHook,
            defaultRedeemHook,
            queueLimit,
            _roleHolders
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation), proxyAdmin, abi.encodeWithSelector(Vault.initialize.selector, initParams)
        );
        return Vault(payable(address(proxy)));
    }

    function _loadAddressFromSlot(address _contract, bytes32 _slot) public view returns (address) {
        bytes32 rawAddress = vm.load(address(_contract), _slot);
        return address(uint160(uint256(rawAddress)));
    }

    function _loadBytes32FromSetSlot(address _contract, bytes32 _baseSlot, uint256 _index)
        public
        view
        returns (bytes32)
    {
        bytes32 arraySlot = SlotDerivation.deriveArray(_baseSlot);
        bytes32 elementSlot = SlotDerivation.offset(arraySlot, _index);
        return vm.load(_contract, elementSlot);
    }

    function _createRoleHolder(bytes32 _role, address _holder) public pure returns (Vault.RoleHolder memory) {
        return Vault.RoleHolder({role: _role, holder: _holder});
    }
}
