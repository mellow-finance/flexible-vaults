// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOracle} from "../oracles/IOracle.sol";
import {ISyncQueue} from "./ISyncQueue.sol";

interface ISyncDepositQueue is ISyncQueue {
    // Erros

    error Forbidden();
    error TooLarge();
    error StaleReport();

    // Structs

    struct SyncDepositQueueStorage {
        uint256 penaltyD6;
        uint32 maxAge;
    }

    // Errors

    error DepositNotAllowed();

    // View functions

    function SET_SYNC_DEPOSIT_PARAMS_ROLE() external view returns (bytes32);

    function syncDepositParams() external view returns (uint256 penaltyD6, uint32 maxAge);

    function claimableOf(address account) external view returns (uint256 claimable);

    // Mutable functions

    function setSyncDepositParams(uint256 syncDepositPenalty_, uint32 maxAge_) external;

    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    function claim(address account) external returns (bool success);

    // Events

    event Deposited(
        address indexed account, address indexed referral, uint224 assets, uint256 shares, uint256 feeShares
    );

    event SyncDepositParamsSet(uint256 penaltyD6, uint32 maxAge);
}
