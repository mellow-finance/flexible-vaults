// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IBoringOnChainQueue {
    struct OnChainWithdraw {
        uint96 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address user; // msg.sender
        address assetOut; // input sanitized
        uint128 amountOfShares; // input transfered in
        uint128 amountOfAssets; // derived from amountOfShares and price
        uint40 creationTime; // time withdraw was made
        uint24 secondsToMaturity; // in contract, from withdrawAsset?
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime add seconds to maturity, add the secondsToDeadline
    }

    function requestOnChainWithdraw(address assetOut, uint128 amountOfShares, uint16 discount, uint24 secondsToDeadline)
        external
        returns (bytes32 requestId);

    function cancelOnChainWithdraw(OnChainWithdraw memory request) external returns (bytes32 requestId);

    function replaceOnChainWithdraw(OnChainWithdraw memory oldRequest, uint16 discount, uint24 secondsToDeadline)
        external
        returns (bytes32 oldRequestId, bytes32 newRequestId);
}
