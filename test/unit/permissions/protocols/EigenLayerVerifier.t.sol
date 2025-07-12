// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../Fixture.t.sol";

contract EigenLayerVerifierTest is Test {
    EigenLayerVerifier internal verifier;

    address internal delegationManager = makeAddr("delegationManager");
    address internal strategyManager = makeAddr("strategyManager");
    address internal rewardsCoordinator = makeAddr("rewardsCoordinator");

    // Entities with roles
    address internal caller = makeAddr("caller");
    address internal mellowVault = makeAddr("mellowVault");
    address internal operator = makeAddr("operator");
    address internal receiver = makeAddr("receiver");
    address internal strategy = makeAddr("strategy");
    address internal asset = makeAddr("asset");

    function setUp() public {
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

        address[] memory holders = new address[](6);
        holders[0] = caller;
        holders[1] = mellowVault;
        holders[2] = operator;
        holders[3] = receiver;
        holders[4] = strategy;
        holders[5] = asset;

        bytes32[] memory roles = new bytes32[](6);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.MELLOW_VAULT_ROLE();
        roles[2] = verifierImplementation.OPERATOR_ROLE();
        roles[3] = verifierImplementation.RECEIVER_ROLE();
        roles[4] = verifierImplementation.STRATEGY_ROLE();
        roles[5] = verifierImplementation.ASSET_ROLE();

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

        verifier = EigenLayerVerifier(address(proxy));
    }

    /**
     * Basic validation tests
     */

    /// @notice Tests that `verifyCall` returns `false` for a call with insufficient call data length.
    function testVerifyCallRevertsOnInsufficientCallDataLength() public view {
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, abi.encodePacked(bytes3(0x123456)), "");
        assertFalse(result, "verifyCall should return false for insufficient calldata length");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with a non-zero value.
    function testVerifyCallRevertsOnNonZeroValue() public view {
        bytes memory validCallData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, 1000);
        bool result = verifier.verifyCall(caller, address(strategyManager), 1, validCallData, "");
        assertFalse(result, "verifyCall should return false for non-zero value");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call from a caller without CALLER_ROLE.
    function testVerifyCallRevertsOnUnauthorizedCaller() public {
        bytes memory validCallData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, 1000);
        address nonAuthorizedCaller = makeAddr("nonAuthorizedCaller");
        bool result = verifier.verifyCall(nonAuthorizedCaller, address(strategyManager), 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for unauthorized caller");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call to an unknown contract.
    function testVerifyCallRevertsOnUnknownContract() public {
        bytes memory validCallData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, 1000);
        address unknownContract = makeAddr("unknownContract");
        bool result = verifier.verifyCall(caller, unknownContract, 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for unknown contract");
    }

    /// @notice Tests that `verifyCall` ignores the verificationData parameter.
    function testVerifyCallIgnoresVerificationData(uint256 random) public view {
        bytes memory callData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, 1000);
        bytes memory verificationData = abi.encode(bytes32(random), "some", "dummy", "data");
        bool result1 = verifier.verifyCall(caller, address(strategyManager), 0, callData, "");
        bool result2 = verifier.verifyCall(caller, address(strategyManager), 0, callData, verificationData);
        assertEq(result1, result2, "verifyCall should ignore verificationData parameter");
    }

    /**
     * StrategyManager tests
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `depositIntoStrategy`.
    function testVerifyCallDepositIntoStrategy(uint256 shares) public view {
        vm.assume(shares > 0);
        bytes memory validCallData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, shares);
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, validCallData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when the strategy doesn't have STRATEGY_ROLE for `depositIntoStrategy`.
    function testVerifyCallDepositIntoStrategyRevertsOnInvalidStrategy() public {
        address unknownStrategy = makeAddr("unknownStrategy");
        bytes memory callData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, unknownStrategy, asset, 1000);
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid strategy");
    }

    /// @notice Tests that `verifyCall` returns `false` when the asset doesn't have ASSET_ROLE for `depositIntoStrategy`.
    function testVerifyCallDepositIntoStrategyRevertsOnInvalidAsset() public {
        address unknownAsset = makeAddr("unknownAsset");
        bytes memory callData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, unknownAsset, 1000);
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid asset");
    }

    /// @notice Tests that `verifyCall` returns `false` when the shares are zero for `depositIntoStrategy`.
    function testVerifyCallDepositIntoStrategyRevertsOnZeroShares() public view {
        bytes memory callData =
            abi.encodeWithSelector(IStrategyManager.depositIntoStrategy.selector, strategy, asset, 0);
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero shares");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `depositIntoStrategy`.
    function testVerifyCallDepositIntoStrategyRevertsOnMalformedCallData() public view {
        bytes memory malformedCallData = abi.encodeWithSelector(
            IStrategyManager.depositIntoStrategy.selector, strategy, asset, uint256(1000), "extra"
        );
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, malformedCallData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector to StrategyManager.
    function testVerifyCallRevertsOnUnknownSelectorStrategyManager() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), "unknown");
        bool result = verifier.verifyCall(caller, address(strategyManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown selector");
    }

    /**
     * DelegationManager tests - delegateTo
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `delegateTo`.
    function testVerifyCallDelegateTo() public view {
        ISignatureUtils.SignatureWithExpiry memory signature = ISignatureUtils.SignatureWithExpiry({
            signature: abi.encodePacked("dummy_signature"),
            expiry: block.timestamp
        });
        bytes memory validCallData =
            abi.encodeWithSelector(IDelegationManager.delegateTo.selector, operator, signature, keccak256("dummy_salt"));
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, validCallData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when the operator doesn't have OPERATOR_ROLE for `delegateTo`.
    function testVerifyCallDelegateToRevertsOnInvalidOperator() public {
        ISignatureUtils.SignatureWithExpiry memory signature = ISignatureUtils.SignatureWithExpiry({
            signature: abi.encodePacked("dummy_signature"),
            expiry: block.timestamp
        });
        address invalidOperator = makeAddr("invalidOperator");
        bytes memory validCallData = abi.encodeWithSelector(
            IDelegationManager.delegateTo.selector, invalidOperator, signature, keccak256("dummy_salt")
        );
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for invalid operator");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `delegateTo`.
    function testVerifyCallDelegateToRevertsOnMalformedCallData() public view {
        ISignatureUtils.SignatureWithExpiry memory signature = ISignatureUtils.SignatureWithExpiry({
            signature: abi.encodePacked("dummy_signature"),
            expiry: block.timestamp
        });
        bytes memory malformedCallData = abi.encodeWithSelector(
            IDelegationManager.delegateTo.selector, operator, signature, keccak256("dummy_salt"), "extra"
        );
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, malformedCallData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * DelegationManager tests - queueWithdrawals
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `queueWithdrawals`.
    function testVerifyCallQueueWithdrawals(uint256 shares) public view {
        vm.assume(shares > 0);
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(strategy);
        params[0].depositShares[0] = shares;
        bytes memory validCallData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, validCallData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when params array length is not 1 for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnInvalidParamsLength() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](2);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[1] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });

        params[0].strategies[0] = IStrategy(strategy);
        params[0].depositShares[0] = 1000;
        params[1].strategies[0] = IStrategy(strategy);
        params[1].depositShares[0] = 2000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid params length");
    }

    /// @notice Tests that `verifyCall` returns `false` when strategies array length is not 1 for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnInvalidStrategiesLength() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](2),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(strategy);
        params[0].strategies[1] = IStrategy(strategy);
        params[0].depositShares[0] = 1000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid strategies length");
    }

    /// @notice Tests that `verifyCall` returns `false` when strategy address is zero for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnZeroStrategyAddress() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(address(0));
        params[0].depositShares[0] = 1000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero strategy address");
    }

    /// @notice Tests that `verifyCall` returns `false` when deposit shares array length is not 1 for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnInvalidDepositSharesLength() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](2),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(strategy);
        params[0].depositShares[0] = 1000;
        params[0].depositShares[1] = 2000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid deposit shares length");
    }

    /// @notice Tests that `verifyCall` returns `false` when deposit shares is zero for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnZeroDepositShares() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(strategy);
        params[0].depositShares[0] = 0;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero deposit shares");
    }

    /// @notice Tests that `verifyCall` returns `false` when the strategy doesn't have STRATEGY_ROLE for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnInvalidStrategy() public {
        address invalidStrategy = makeAddr("invalidStrategy");
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(invalidStrategy);
        params[0].depositShares[0] = 1000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid strategy");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `queueWithdrawals`.
    function testVerifyCallQueueWithdrawalsRevertsOnMalformedCallData() public view {
        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);
        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            depositShares: new uint256[](1),
            __deprecated_withdrawer: address(0)
        });
        params[0].strategies[0] = IStrategy(strategy);
        params[0].depositShares[0] = 1000;

        bytes memory callData = abi.encodeWithSelector(IDelegationManager.queueWithdrawals.selector, params, "extra");
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /**
     * DelegationManager tests - completeQueuedWithdrawal
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawal(uint256 shares) public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = shares;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertTrue(result, "verifyCall should return true for valid call");
    }

    /// @notice Tests that `verifyCall` returns `false` when tokens array length is not 1 for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnInvalidTokensLength() public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](2);
        tokens[0] = asset;
        tokens[1] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid tokens length");
    }

    /// @notice Tests that `verifyCall` returns `false` when receiveAsTokens is false for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnReceiveAsTokensFalse() public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, false);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for receiveAsTokens false");
    }

    /// @notice Tests that `verifyCall` returns `false` when the staker doesn't have MELLOW_VAULT_ROLE for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnInvalidStaker() public {
        address invalidStaker = makeAddr("invalidStaker");
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: invalidStaker,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid staker");
    }

    /// @notice Tests that `verifyCall` returns `false` when withdrawal strategies length is not 1 for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnInvalidWithdrawalStrategiesLength() public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](2),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.strategies[1] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid withdrawal strategies length");
    }

    /// @notice Tests that `verifyCall` returns `false` when withdrawal strategy address is zero for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnZeroWithdrawalStrategyAddress() public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(address(0));
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for zero withdrawal strategy address");
    }

    /// @notice Tests that `verifyCall` returns `false` when the strategy doesn't have STRATEGY_ROLE for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnInvalidStrategy() public {
        address invalidStrategy = makeAddr("invalidStrategy");
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(invalidStrategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid strategy");
    }

    /// @notice Tests that `verifyCall` returns `false` when the token doesn't have ASSET_ROLE for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = invalidToken;

        bytes memory callData =
            abi.encodeWithSelector(IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true);
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for invalid token");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `completeQueuedWithdrawal`.
    function testVerifyCallCompleteQueuedWithdrawalRevertsOnMalformedCallData() public view {
        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: mellowVault,
            delegatedTo: operator,
            withdrawer: caller,
            nonce: 0,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = 1000;

        address[] memory tokens = new address[](1);
        tokens[0] = asset;

        bytes memory callData = abi.encodeWithSelector(
            IDelegationManager.completeQueuedWithdrawal.selector, withdrawal, tokens, true, "extra"
        );
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector to DelegationManager.
    function testVerifyCallRevertsOnUnknownSelectorDelegationManager() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), "unknown");
        bool result = verifier.verifyCall(caller, address(delegationManager), 0, callData, "");
        assertFalse(result, "verifyCall should return false for unknown selector");
    }

    /**
     * RewardsCoordinator tests
     */

    /// @notice Tests that the verifier correctly verifies a valid call to `processClaim`.
    function testVerifyCallProcessClaim(uint256 cumulativeEarnings) public view {
        bytes memory validCallData = abi.encodeWithSelector(
            IRewardsCoordinator.processClaim.selector, _generatedClaimData(mellowVault, cumulativeEarnings), receiver
        );
        bool result = verifier.verifyCall(caller, address(rewardsCoordinator), 0, validCallData, "");
        assertTrue(result, "verifyCall should return true for valid processClaim call");
    }

    /// @notice Tests that `verifyCall` returns `false` when the earner doesn't have MELLOW_VAULT_ROLE for `processClaim`.
    function testVerifyCallProcessClaimRevertsOnInvalidEarner() public {
        address invalidEarner = makeAddr("invalidEarner");
        bytes memory validCallData = abi.encodeWithSelector(
            IRewardsCoordinator.processClaim.selector, _generatedClaimData(invalidEarner, 1000), receiver
        );
        bool result = verifier.verifyCall(caller, address(rewardsCoordinator), 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for invalid earner");
    }

    /// @notice Tests that `verifyCall` returns `false` when the receiver doesn't have RECEIVER_ROLE for `processClaim`.
    function testVerifyCallProcessClaimRevertsOnInvalidReceiver() public {
        address invalidReceiver = makeAddr("invalidReceiver");
        bytes memory validCallData = abi.encodeWithSelector(
            IRewardsCoordinator.processClaim.selector, _generatedClaimData(mellowVault, 1000), invalidReceiver
        );
        bool result = verifier.verifyCall(caller, address(rewardsCoordinator), 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for invalid receiver");
    }

    /// @notice Tests that `verifyCall` returns `false` when callData has extra bytes for `processClaim`.
    function testVerifyCallProcessClaimRevertsOnMalformedCallData() public view {
        bytes memory validCallData = abi.encodeWithSelector(
            IRewardsCoordinator.processClaim.selector, _generatedClaimData(mellowVault, 1000), receiver, "extra"
        );
        bool result = verifier.verifyCall(caller, address(rewardsCoordinator), 0, validCallData, "");
        assertFalse(result, "verifyCall should return false for malformed call data");
    }

    /// @notice Tests that `verifyCall` returns `false` for a call with an unknown selector to RewardsCoordinator.
    function testVerifyCallRevertsOnUnknownSelectorRewardsCoordinator() public view {
        bytes memory callData = abi.encodeWithSelector(bytes4(0), "unknown");
        bool result = verifier.verifyCall(caller, address(rewardsCoordinator), 0, callData, "");
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
        roles[0] = verifier.OPERATOR_ROLE();

        vm.expectRevert();
        verifier.initialize(abi.encode(address(this), holders, roles));
    }

    /// @notice Tests that the `initialize` function reverts if the admin address is zero.
    function testInitializeRevertsOnZeroAdmin() public {
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

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
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

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
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

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
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

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
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

        address[] memory holders = new address[](3);
        holders[0] = caller;
        holders[1] = mellowVault;
        holders[2] = operator;

        bytes32[] memory roles = new bytes32[](3);
        roles[0] = verifierImplementation.CALLER_ROLE();
        roles[1] = verifierImplementation.MELLOW_VAULT_ROLE();
        roles[2] = verifierImplementation.OPERATOR_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        EigenLayerVerifier verifierProxy = EigenLayerVerifier(address(proxy));
        for (uint256 i = 0; i < holders.length; i++) {
            assertTrue(verifierProxy.hasRole(roles[i], holders[i]), "Role not granted correctly");
        }
    }

    /// @notice Tests that the `initialize` function correctly grants DEFAULT_ADMIN_ROLE to admin.
    function testInitializeCorrectlyGrantsAdminRole() public {
        EigenLayerVerifier verifierImplementation =
            new EigenLayerVerifier(delegationManager, strategyManager, rewardsCoordinator, "EigenLayer Verifier", 1);

        address[] memory holders = new address[](1);
        holders[0] = caller;

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = verifierImplementation.CALLER_ROLE();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(verifierImplementation),
            address(this),
            abi.encodeWithSelector(OwnedCustomVerifier.initialize.selector, abi.encode(address(this), holders, roles))
        );

        EigenLayerVerifier verifierProxy = EigenLayerVerifier(address(proxy));
        assertTrue(
            verifierProxy.hasRole(verifierImplementation.DEFAULT_ADMIN_ROLE(), address(this)),
            "Admin role not granted correctly"
        );
    }

    /**
     * Helper functions
     */

    /// @notice Generates a valid payload for the `IRewardsCoordinator.processClaim` function verifier.
    function _generatedClaimData(address _earner, uint256 _cumulativeEarnings)
        public
        view
        returns (IRewardsCoordinator.RewardsMerkleClaim memory)
    {
        // Create a valid EarnerTreeMerkleLeaf
        IRewardsCoordinator.EarnerTreeMerkleLeaf memory earnerLeaf =
            IRewardsCoordinator.EarnerTreeMerkleLeaf({earner: _earner, earnerTokenRoot: keccak256("earnerTokenRoot")});

        // Create a valid TokenTreeMerkleLeaf
        IRewardsCoordinator.TokenTreeMerkleLeaf[] memory tokenLeaves = new IRewardsCoordinator.TokenTreeMerkleLeaf[](1);
        tokenLeaves[0] =
            IRewardsCoordinator.TokenTreeMerkleLeaf({token: IERC20(asset), cumulativeEarnings: _cumulativeEarnings});

        // Create arrays for indices and proofs
        uint32[] memory tokenIndices = new uint32[](1);
        tokenIndices[0] = 0;

        bytes[] memory tokenTreeProofs = new bytes[](1);
        tokenTreeProofs[0] = abi.encodePacked(bytes32(keccak256("tokenTreeProof")));

        // Create a valid RewardsMerkleClaim
        return IRewardsCoordinator.RewardsMerkleClaim({
            rootIndex: 1,
            earnerIndex: 0,
            earnerTreeProof: abi.encodePacked(bytes32(keccak256("earnerTreeProof"))),
            earnerLeaf: earnerLeaf,
            tokenIndices: tokenIndices,
            tokenTreeProofs: tokenTreeProofs,
            tokenLeaves: tokenLeaves
        });
    }
}
