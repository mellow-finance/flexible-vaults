// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../Fixture.t.sol";

contract SymbioticVerifierTest is Test {
    SymbioticVerifier internal verifier;

    address internal vaultFactory = makeAddr("vaultFactory");
    address internal farmFactory = makeAddr("farmFactory");

    // Entities with roles
    address internal caller = makeAddr("caller");
    address internal mellowVault = makeAddr("mellowVault");
    address internal token = makeAddr("token");
    address internal symbioticVault = makeAddr("symbioticVault");
    address internal symbioticFarm = makeAddr("symbioticFarm");

    function setUp() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](4);
        holders[0] = caller;
        holders[1] = mellowVault;
        holders[2] = symbioticVault;
        holders[3] = symbioticFarm;

        bytes32[] memory roles = new bytes32[](4);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.MELLOW_VAULT_ROLE();
        roles[2] = verifierImplementation.SYMBIOTIC_VAULT_ROLE();
        roles[3] = verifierImplementation.SYMBIOTIC_FARM_ROLE();

        // Check all roles are distinct
        for (uint256 i = 0; i < roles.length; i++) {
            for (uint256 j = i + 1; j < roles.length; j++) {
                assertTrue(roles[i] != roles[j], "All roles should be distinct");
            }
        }

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        verifier = SymbioticVerifier(address(proxy));
    }

    /**
     * Basic validation tests
     */

    /// @notice Tests that `verifyCall` returns `false` for a call with insufficient call data length.
    function testVerifyCallRevertsOnInsufficientCallDataLength() public view {
        bool result = verifier.verifyCall(caller, symbioticVault, 0, abi.encodePacked(bytes3(0x123456)), "");
        assertFalse(result, "verifyCall should return false for insufficient calldata length");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with a non-zero value.
    function testVerifyCallRevertsOnNonZeroValue() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 1);
        bool result = verifier.verifyCall(caller, symbioticVault, 1, callData, "");
        assertFalse(result, "verifyCall should return false for non-zero value");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call from a caller without CALLER_ROLE.
    function testVerifyCallRevertsOnUnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorizedCaller");
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 1);
        bool result = verifier.verifyCall(unauthorizedCaller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unauthorized caller");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call to an unknown contract (no SYMBIOTIC_VAULT_ROLE or SYMBIOTIC_FARM_ROLE).
    function testVerifyCallRevertsOnUnknownContract() public {
        address unknownContract = makeAddr("unknownContract");
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 1);
        bool result = verifier.verifyCall(caller, unknownContract, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown contract");
    }

    /// @notice Tests that `verifyCall` ignores the verificationData parameter.
    function testVerifyCallIgnoresVerificationData(uint256 random) public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 1000);
        bytes memory verificationData = abi.encode(bytes32(random), "some", "dummy", "data");
        bool result1 = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        bool result2 = verifier.verifyCall(caller, symbioticVault, 0, callData, verificationData);
        assertEq(result1, result2, "verifyCall should ignore verificationData parameter");
    }

    /**
     * SymbioticVault tests - deposit
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `deposit`.
    function testVerifyCallDeposit(uint256 amount) public view {
        vm.assume(amount > 0);
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, amount);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when onBehalfOf doesn't have MELLOW_VAULT_ROLE for `deposit`.
    function testVerifyCallDepositRevertsOnInvalidOnBehalfOf() public {
        address invalidOnBehalfOf = makeAddr("invalidOnBehalfOf");
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, invalidOnBehalfOf, 1000);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid onBehalfOf");
    }

    /// @notice Tests that `verifyCall` returns `false` when amount is zero for `deposit`.
    function testVerifyCallDepositRevertsOnZeroAmount() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 0);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false when amount is zero");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `deposit`.
    function testVerifyCallDepositRevertsOnMalformedCallData() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.deposit.selector, mellowVault, 1000, "extra");
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * SymbioticVault tests - withdraw
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `withdraw`.
    function testVerifyCallWithdraw(uint256 amount) public view {
        vm.assume(amount > 0);
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.withdraw.selector, mellowVault, amount);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when claimer doesn't have MELLOW_VAULT_ROLE for `withdraw`.
    function testVerifyCallWithdrawRevertsOnInvalidClaimer() public {
        address invalidClaimer = makeAddr("invalidClaimer");
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.withdraw.selector, invalidClaimer, 1000);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid claimer");
    }

    /// @notice Tests that `verifyCall` returns `false` when amount is zero for `withdraw`.
    function testVerifyCallWithdrawRevertsOnZeroAmount() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.withdraw.selector, mellowVault, 0);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false when amount is zero");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `withdraw`.
    function testVerifyCallWithdrawRevertsOnMalformedCallData() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.withdraw.selector, mellowVault, 1000, "extra");
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * SymbioticVault tests - claim
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `claim`.
    function testVerifyCallClaim(uint256 epoch) public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.claim.selector, mellowVault, epoch);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when recipient doesn't have MELLOW_VAULT_ROLE for `claim`.
    function testVerifyCallClaimRevertsOnInvalidRecipient() public {
        address invalidRecipient = makeAddr("invalidRecipient");
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.claim.selector, invalidRecipient, 0);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `claim`.
    function testVerifyCallClaimRevertsOnMalformedCallData() public view {
        bytes memory callData = abi.encodeWithSelector(ISymbioticVault.claim.selector, mellowVault, 0, "extra");
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * SymbioticVault tests - unknown selector
     */

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector to a SYMBIOTIC_VAULT_ROLE contract.
    function testVerifyCallSymbioticVaultRevertsOnUnknownSelector() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), mellowVault, 256);
        bool result = verifier.verifyCall(caller, symbioticVault, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown selector");
    }

    /**
     * SymbioticFarm tests - claimRewards
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `claimRewards`.
    function testVerifyCallClaimRewards() public view {
        bytes memory callData =
            abi.encodeWithSelector(ISymbioticStakerRewards.claimRewards.selector, mellowVault, token, "data");
        bool result = verifier.verifyCall(caller, symbioticFarm, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when recipient doesn't have MELLOW_VAULT_ROLE for `claimRewards`.
    function testVerifyCallClaimRewardsRevertsOnInvalidRecipient() public {
        address invalidRecipient = makeAddr("invalidRecipient");
        bytes memory callData =
            abi.encodeWithSelector(ISymbioticStakerRewards.claimRewards.selector, invalidRecipient, token, "data");
        bool result = verifier.verifyCall(caller, symbioticFarm, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when token is zero address for `claimRewards`.
    function testVerifyCallClaimRewardsRevertsOnZeroToken() public view {
        bytes memory callData =
            abi.encodeWithSelector(ISymbioticStakerRewards.claimRewards.selector, mellowVault, address(0), "data");
        bool result = verifier.verifyCall(caller, symbioticFarm, 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero token");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `claimRewards`.
    function testVerifyCallClaimRewardsRevertsOnMalformedCallData() public view {
        bytes memory callData =
            abi.encodeWithSelector(ISymbioticStakerRewards.claimRewards.selector, mellowVault, token, "data", "extra");
        bool result = verifier.verifyCall(caller, symbioticFarm, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * SymbioticFarm tests - unknown selector
     */

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector to a SYMBIOTIC_FARM_ROLE contract.
    function testVerifyCallSymbioticFarmRevertsOnUnknownSelector() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), mellowVault, token, "data");
        bool result = verifier.verifyCall(caller, symbioticFarm, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown selector");
    }

    /**
     * Initialization tests
     */

    /// @notice Tests that the `initialize` function can only be called once.
    function testInitializeRevertsIfCalledTwice() public {
        address[] memory holders = new address[](1);
        holders[0] = makeAddr("culprit");

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifier.CALLER_ROLE();

        vm.expectRevert();
        verifier.initialize(abi.encode(address(this), holders, roles));
    }

    /// @notice Tests that the `initialize` function reverts if the admin address is zero.
    function testInitializeRevertsOnZeroAdmin() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = caller;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        address zeroAdminAddress = address(0);

        vm.expectRevert(abi.encodeWithSelector(OwnedCustomVerifier.ZeroValue.selector));
        new TransparentUpgradeableProxy(
            address(verifierImplementation),
            zeroAdminAddress,
            abi.encodeWithSelector(
                OwnedCustomVerifier.initialize.selector, abi.encode(zeroAdminAddress, holders, roles)
            )
        );
    }

    /// @notice Tests that the `initialize` function reverts if a holder address is zero.
    function testInitializeRevertsOnZeroHolder() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = address(0);

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        vm.expectRevert(abi.encodeWithSelector(OwnedCustomVerifier.ZeroValue.selector));
        new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );
    }

    /// @notice Tests that the `initialize` function reverts if a role is zero.
    function testInitializeRevertsOnZeroRole() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = caller;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = bytes32(0);

        vm.expectRevert(abi.encodeWithSelector(OwnedCustomVerifier.ZeroValue.selector));
        new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );
    }

    /// @notice Tests that the `initialize` function reverts on array length mismatch (more holders than roles).
    function testInitializeWithArrayLengthMismatchMoreHolders() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](2);
        holders[0] = caller;
        holders[1] = mellowVault;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x32)); // array out-of-bounds access (0x32)
        new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );
    }

    /// @notice Tests that the `initialize` function correctly grants roles to holders.
    function testInitializeCorrectlyGrantsRoles() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](4);
        holders[0] = caller;
        holders[1] = mellowVault;
        holders[2] = symbioticVault;
        holders[3] = symbioticFarm;

        bytes32[] memory roles = new bytes32[](4);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.MELLOW_VAULT_ROLE();
        roles[2] = verifierImplementation.SYMBIOTIC_VAULT_ROLE();
        roles[3] = verifierImplementation.SYMBIOTIC_FARM_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        SymbioticVerifier verifierProxy = SymbioticVerifier(address(proxy));
        for (uint256 i = 0; i < holders.length; i++) {
            assertTrue(verifierProxy.hasRole(roles[i], holders[i]), "Role not granted correctly");
        }
    }

    /// @notice Tests that the `initialize` function correctly grants DEFAULT_ADMIN_ROLE to admin.
    function testInitializeCorrectlyGrantsAdminRole() public {
        SymbioticVerifier verifierImplementation =
            new SymbioticVerifier(vaultFactory, farmFactory, "Symbiotic Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = caller;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        SymbioticVerifier verifierProxy = SymbioticVerifier(address(proxy));
        assertTrue(
            verifierProxy.hasRole(verifierImplementation.DEFAULT_ADMIN_ROLE(), address(this)),
            "Admin role not granted correctly"
        );
    }
}
