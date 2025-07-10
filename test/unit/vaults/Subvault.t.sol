// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract SubvaultTest is Test {
    address internal proxyAdmin = makeAddr("proxyAdmin");
    address internal verifier = makeAddr("verifier");
    address internal vault = makeAddr("vault");

    /**
     * Constructor tests
     */

    /// @notice Tests that the constructor utilizes the name and version to set the unique storage slot for verifier parent module.
    function testConstructorSetsUniqueVerifierModuleSlot() public {
        uint256 version = 1;
        string memory name = "Subvault";
        string memory moduleName = "VerifierModule";

        Subvault subvault = _createSubvault(name, version);

        // Ensure the verifier address is stored correctly
        {
            bytes32 verifierModuleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedVerifier = _loadAddressFromSlot(address(subvault), verifierModuleSlot);
            assertEq(storedVerifier, verifier, "verifier address mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 verifierModuleSlot = SlotLibrary.getSlot(moduleName, name, version + 1);
            address storedVerifier = _loadAddressFromSlot(address(subvault), verifierModuleSlot);
            assertNotEq(storedVerifier, verifier, "verifier should not be set for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 verifierModuleSlot = SlotLibrary.getSlot(moduleName, "", version);
            address storedVerifier = _loadAddressFromSlot(address(subvault), verifierModuleSlot);
            assertNotEq(storedVerifier, verifier, "verifier should not be set for different name");
        }
    }

    /// @notice Tests that the constructor utilizes the name and version to set the unique storage slot for vault parent module.
    function testConstructorSetsUniqueVaultModuleSlot() public {
        uint256 version = 1;
        string memory name = "Subvault";
        string memory moduleName = "SubvaultModule";

        Subvault subvault = _createSubvault(name, version);

        // Ensure the vault address is stored correctly
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, name, version);
            address storedVault = _loadAddressFromSlot(address(subvault), vaultModuleSlot);
            assertEq(storedVault, vault, "vault address mismatch");
        }

        // Ensure there will be no collisions (version is respected)
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, name, version + 1);
            address storedVault = _loadAddressFromSlot(address(subvault), vaultModuleSlot);
            assertNotEq(storedVault, vault, "vault should not be set for different version");
        }

        // Ensure there will be no collisions (name is respected)
        {
            bytes32 vaultModuleSlot = SlotLibrary.getSlot(moduleName, "", version);
            address storedVault = _loadAddressFromSlot(address(subvault), vaultModuleSlot);
            assertNotEq(storedVault, vault, "vault should not be set for different name");
        }
    }

    /**
     * Initialize function tests
     */

    /// @notice Tests that the initialize function correctly sets the correct verifier address.
    function testInitializeSetsVerifier() public {
        Subvault subvault = _createSubvault("Subvault", 1);
        assertEq(address(subvault.verifier()), verifier);
    }

    /// @notice Tests that the initialize function correctly sets the correct vault address.
    function testInitializeSetsVault() public {
        Subvault subvault = _createSubvault("Subvault", 1);
        assertEq(address(subvault.vault()), vault);
    }

    /// @notice Tests that the initialize function can only be called once.
    function testInitializeRevertsIfCalledTwice() public {
        Subvault subvault = _createSubvault("Subvault", 1);
        vm.expectRevert();
        subvault.initialize(abi.encode(verifier, vault));
    }

    /// @notice Tests that the initialize function emits Initialized event.
    function testInitializeEmitsInitializedEvent() public {
        Subvault subvaultImplementation = new Subvault("Subvault", 1);
        bytes memory initParams = abi.encode(verifier, vault);

        vm.expectEmit(true, true, true, true);
        emit IFactoryEntity.Initialized(initParams);

        new TransparentUpgradeableProxy(
            address(subvaultImplementation),
            proxyAdmin,
            abi.encodeWithSelector(Subvault.initialize.selector, initParams)
        );
    }

    /// @notice Tests that the initialize function reverts with malformed parameters.
    function testInitializeRevertsOnMalformedParameters() public {
        Subvault subvaultImplementation = new Subvault("Subvault", 1);
        bytes memory malformedParams = abi.encode(address(0), bytes32(0), 128);

        vm.expectRevert();
        new TransparentUpgradeableProxy(
            address(subvaultImplementation),
            proxyAdmin,
            abi.encodeWithSelector(Subvault.initialize.selector, malformedParams)
        );
    }

    /// @notice Tests that the initialize function reverts with insufficient parameters.
    function testInitializeRevertsOnInsufficientParameters() public {
        Subvault subvaultImplementation = new Subvault("Subvault", 1);
        bytes memory malformedParams = abi.encode(verifier);

        vm.expectRevert();
        new TransparentUpgradeableProxy(
            address(subvaultImplementation),
            proxyAdmin,
            abi.encodeWithSelector(Subvault.initialize.selector, malformedParams)
        );
    }

    /**
     * Helper functions
     */
    function _createSubvault(string memory _name, uint256 _version) public returns (Subvault) {
        Subvault subvaultImplementation = new Subvault(_name, _version);
        bytes memory initParams = abi.encode(verifier, vault);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(subvaultImplementation),
            proxyAdmin,
            abi.encodeWithSelector(Subvault.initialize.selector, initParams)
        );
        return Subvault(payable(address(proxy)));
    }

    function _loadAddressFromSlot(address _contract, bytes32 _slot) public view returns (address) {
        bytes32 rawAddress = vm.load(address(_contract), _slot);
        return address(uint160(uint256(rawAddress)));
    }
}
