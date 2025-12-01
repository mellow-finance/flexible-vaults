// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOracle} from "../oracles/IOracle.sol";
import {ISyncQueue} from "./ISyncQueue.sol";

interface ISyncDepositQueue is ISyncQueue {
    // Erros

    error Forbidden();
    error TooLarge();

    // Structs

    struct SyncDepositQueueStorage {
        uint256 syncDepositPenaltyD6;
    }

    // Errors

    error DepositNotAllowed();

    // View functions

    function SET_SYNC_DEPOSIT_PENALTY_ROLE() external view returns (bytes32);

    function claimableOf(address account) external view returns (uint256 claimable);

    // Mutable functions

    function setSyncDepositPenaltyD6(uint256 syncDepositPenalty_) external;

    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    function claim(address account) external returns (bool success);

    // Events

    event Deposited(address indexed account, address indexed referral, uint224 assets);

    event SyncDepositPenaltySet(uint256 syncDepositPenalty);
}
