// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/external/eigen-layer/IDelegationManager.sol";
import "../../interfaces/external/eigen-layer/IRewardsCoordinator.sol";
import "../../interfaces/external/eigen-layer/IStrategyManager.sol";

import "./OwnedCustomVerifier.sol";

contract EigenLayerVerifier is OwnedCustomVerifier {
    bytes32 public constant ASSET_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.ASSET_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.CALLER_ROLE");
    bytes32 public constant MELLOW_VAULT_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.MELLOW_VAULT_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.OPERATOR_ROLE");
    bytes32 public constant RECEIVER_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.RECEIVER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("permissions.protocols.EigenLayerVerifier.STRATEGY_ROLE");

    IDelegationManager public immutable delegationManager;
    IStrategyManager public immutable strategyManager;
    IRewardsCoordinator public immutable rewardsCoordinator;

    constructor(
        address delegationManager_,
        address strategyManager_,
        address rewardsCoordinator_,
        string memory name_,
        uint256 version_
    ) OwnedCustomVerifier(name_, version_) {
        delegationManager = IDelegationManager(delegationManager_);
        strategyManager = IStrategyManager(strategyManager_);
        rewardsCoordinator = IRewardsCoordinator(rewardsCoordinator_);
    }

    // View functions

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (callData.length < 4 || value != 0 || !hasRole(CALLER_ROLE, who)) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        if (where == address(strategyManager)) {
            if (selector == IStrategyManager.depositIntoStrategy.selector) {
                (IStrategy strategy, address asset, uint256 shares) =
                    abi.decode(callData[4:], (IStrategy, address, uint256));
                if (!hasRole(STRATEGY_ROLE, address(strategy)) || !hasRole(ASSET_ROLE, asset) || shares == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, strategy, asset, shares)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (where == address(delegationManager)) {
            if (selector == IDelegationManager.delegateTo.selector) {
                (address operator, ISignatureUtils.SignatureWithExpiry memory signature, bytes32 approverSalt) =
                    abi.decode(callData[4:], (address, ISignatureUtils.SignatureWithExpiry, bytes32));
                if (!hasRole(OPERATOR_ROLE, operator)) {
                    return false;
                }
                if (
                    keccak256(abi.encodeWithSelector(selector, operator, signature, approverSalt))
                        != keccak256(callData)
                ) {
                    return false;
                }
            } else if (selector == IDelegationManager.queueWithdrawals.selector) {
                IDelegationManager.QueuedWithdrawalParams[] memory params =
                    abi.decode(callData[4:], (IDelegationManager.QueuedWithdrawalParams[]));
                if (params.length != 1) {
                    return false;
                }
                IDelegationManager.QueuedWithdrawalParams memory param = params[0];
                if (
                    param.strategies.length != 1 || address(param.strategies[0]) == address(0)
                        || param.depositShares.length != 1 || param.depositShares[0] == 0
                        || !hasRole(STRATEGY_ROLE, address(param.strategies[0]))
                ) {
                    return false;
                }
                if (keccak256(callData) != keccak256(abi.encodeWithSelector(selector, params))) {
                    return false;
                }
            } else if (selector == IDelegationManager.completeQueuedWithdrawal.selector) {
                (IDelegationManager.Withdrawal memory withdrawal, address[] memory tokens, bool receiveAsTokens) =
                    abi.decode(callData[4:], (IDelegationManager.Withdrawal, address[], bool));

                IStrategy strategy = withdrawal.strategies[0];
                if (
                    tokens.length != 1 || !receiveAsTokens || !hasRole(MELLOW_VAULT_ROLE, withdrawal.staker)
                        || withdrawal.strategies.length != 1 || address(strategy) == address(0)
                        || !hasRole(STRATEGY_ROLE, address(strategy)) || !hasRole(ASSET_ROLE, tokens[0])
                ) {
                    return false;
                }
                if (
                    keccak256(abi.encodeWithSelector(selector, withdrawal, tokens, receiveAsTokens))
                        != keccak256(callData)
                ) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (where == address(rewardsCoordinator)) {
            if (selector == IRewardsCoordinator.processClaim.selector) {
                (IRewardsCoordinator.RewardsMerkleClaim memory claimData, address receiver) =
                    abi.decode(callData[4:], (IRewardsCoordinator.RewardsMerkleClaim, address));
                if (!hasRole(MELLOW_VAULT_ROLE, claimData.earnerLeaf.earner)) {
                    return false;
                }
                if (!hasRole(RECEIVER_ROLE, receiver)) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, claimData, receiver)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
        return true;
    }
}
