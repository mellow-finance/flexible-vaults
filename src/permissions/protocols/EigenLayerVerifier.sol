// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomVerifier.sol";

contract EigenLayerVerifier is CustomVerifier {
    address public immutable delegationManager;
    address public immutable strategyManager;
    address public immutable rewardsCoordinator;

    constructor(address _delegationManager, address _strategyManager, address _rewardsCoordinator) {
        delegationManager = _delegationManager;
        strategyManager = _strategyManager;
        rewardsCoordinator = _rewardsCoordinator;
    }

    /*
        TODO: add
        1. StrategyManager:depositIntoStrategy(strategy, asset, assets)
        2. DelegationManager:delegateTo(operator, signature, salt)
        3. DelegationManager:queueWithdrawals(requests)
        4. DelegationManager:completeQueuedWithdrawal(data, tokens, true)
        5. RewardsCoordinator.processClaim(IRewardsCoordinator.RewardsMerkleClaim claimData, receiver)
    */
    function verifyCall(
        address, /* who */
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (callData.length < 4) {
            return false; // Invalid call data
        }
        if (value != 0) {
            return false;
        }
        if (where == address(strategyManager)) {} else if (where == address(delegationManager)) {} else if (
            where == address(rewardsCoordinator)
        ) {} else {
            return false;
        }

        return true;
    }
}
