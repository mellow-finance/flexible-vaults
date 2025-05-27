// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../CustomVerifier.sol";

contract EigenLayerVerifier is CustomVerifier {
    /*
        TODO: add
        1. RewardsCoordinator.processClaim(IRewardsCoordinator.RewardsMerkleClaim, receiver)
        2. DelegationManager:delegateTo(operator, signature, salt)
        3. StrategyManager:depositIntoStrategy(strategy, asset, assets)
        4. DelegationManager:completeQueuedWithdrawal(data, tokens, true)
        5. DelegationManager:queueWithdrawals(requests)
    */
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) external view override returns (bool) {}
}
