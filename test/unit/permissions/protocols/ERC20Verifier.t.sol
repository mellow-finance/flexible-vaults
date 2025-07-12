// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../Fixture.t.sol";

contract ERC20VerifierTest is Test {
    ERC20Verifier internal verifier;

    address internal caller = makeAddr("caller");
    address internal asset = makeAddr("asset");
    address internal recipient = makeAddr("recipient");

    function setUp() public {
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

        address[] memory holders = new address[](3);
        holders[0] = caller;
        holders[1] = asset;
        holders[2] = recipient;

        bytes32[] memory roles = new bytes32[](3);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.ASSET_ROLE();
        roles[2] = verifierImplementation.RECIPIENT_ROLE();

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

        verifier = ERC20Verifier(address(proxy));
    }

    /**
     * Basic validation tests
     */

    /// @notice Tests that `verifyCall` returns `false` for a call with non-zero value.
    function testVerifyCallRevertsOnNonZeroValue() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 1000);
        bool result = verifier.verifyCall(caller, asset, 1, callData, "");
        assertFalse(result, "verifyCall should return false for non-zero value");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with insufficient call data length (less than 68 bytes).
    function testVerifyCallRevertsOnInsufficientCallData() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for insufficient call data length");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call to a contract without ASSET_ROLE.
    function testVerifyCallRevertsOnInvalidAsset() public {
        address invalidAsset = makeAddr("invalidAsset");
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 1000);
        bool result = verifier.verifyCall(caller, invalidAsset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid asset");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call from a caller without CALLER_ROLE.
    function testVerifyCallRevertsOnUnauthorizedCaller() public {
        address invalidCaller = makeAddr("invalidCaller");
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 1000);
        bool result = verifier.verifyCall(invalidCaller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unauthorized caller");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector (not approve or transfer).
    function testVerifyCallRevertsOnUnknownSelector() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), recipient, 1000);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown selector");
    }

    /// @notice Tests that `verifyCall` ignores the verificationData parameter.
    function testVerifyCallIgnoresVerificationData(uint256 random) public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 1000);
        bytes memory verificationData = abi.encode(bytes32(random), "some", "dummy", "data");
        bool result1 = verifier.verifyCall(caller, asset, 0, callData, "");
        bool result2 = verifier.verifyCall(caller, asset, 0, callData, verificationData);
        assertEq(result1, result2, "verifyCall should ignore verificationData parameter");
    }

    /**
     * ERC20 approve function verification tests
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `approve`.
    function testVerifyCallApprove(uint256 amount) public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, amount);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that the verifier correctly verifies a call to `approve` with zero amount.
    function testVerifyCallApproveWithZeroAmount() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 0);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertTrue(result, "verifyCall should return true for approve with zero amount");
    }

    /// @notice Tests that `verifyCall` returns `false` when the recipient address is zero for `approve`.
    function testVerifyCallApproveRevertsOnZeroRecipient() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, address(0), 1000);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when the recipient doesn't have RECIPIENT_ROLE for `approve`.
    function testVerifyCallApproveRevertsOnInvalidRecipient() public {
        address invalidRecipient = makeAddr("invalidRecipient");
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, invalidRecipient, 1000);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `approve`.
    function testVerifyCallApproveRevertsOnMalformedCallData() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.approve.selector, recipient, 1000, "extra");
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * ERC20 transfer function verification tests
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `transfer` with non-zero amount.
    function testVerifyCallTransfer(uint256 amount) public view {
        vm.assume(amount > 0);
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when the amount is zero for `transfer`.
    function testVerifyCallTransferRevertsOnZeroAmount() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, 0);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero amount");
    }

    /// @notice Tests that `verifyCall` returns `false` when the recipient address is zero for `transfer`.
    function testVerifyCallTransferRevertsOnZeroRecipient() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, address(0), 0);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when the recipient doesn't have RECIPIENT_ROLE for `transfer`.
    function testVerifyCallTransferRevertsOnInvalidRecipient() public {
        address invalidRecipient = makeAddr("invalidRecipient");
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, invalidRecipient, 0);
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid recipient");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `transfer`.
    function testVerifyCallTransferRevertsOnMalformedCallData() public view {
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, 1000, "extra");
        bool result = verifier.verifyCall(caller, asset, 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
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
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

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
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

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
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

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
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

        address[] memory holders = new address[](2);
        holders[0] = caller;
        holders[1] = asset;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x32)); // array out-of-bounds access (0x32
        new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );
    }

    /// @notice Tests that the `initialize` function correctly grants roles to holders.
    function testInitializeCorrectlyGrantsRoles() public {
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

        address[] memory holders = new address[](3);
        holders[0] = caller;
        holders[1] = asset;
        holders[2] = recipient;

        bytes32[] memory roles = new bytes32[](3);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.ASSET_ROLE();
        roles[2] = verifierImplementation.RECIPIENT_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        ERC20Verifier verifierProxy = ERC20Verifier(address(proxy));
        for (uint256 i = 0; i < holders.length; i++) {
            assertTrue(verifierProxy.hasRole(roles[i], holders[i]), "Role not granted correctly");
        }
    }

    /// @notice Tests that the `initialize` function correctly grants DEFAULT_ADMIN_ROLE to admin.
    function testInitializeCorrectlyGrantsAdminRole() public {
        ERC20Verifier verifierImplementation = new ERC20Verifier("ERC20 Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = caller;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        ERC20Verifier verifierProxy = ERC20Verifier(address(proxy));
        assertTrue(
            verifierProxy.hasRole(verifierImplementation.DEFAULT_ADMIN_ROLE(), address(this)),
            "Admin role not granted correctly"
        );
    }
}
