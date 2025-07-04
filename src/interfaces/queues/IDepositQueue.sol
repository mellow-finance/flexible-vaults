// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import "../../libraries/FenwickTreeLibrary.sol";

import "../managers/IRiskManager.sol";
import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "./IQueue.sol";

interface IDepositQueue is IQueue {
    error DepositNotAllowed();
    error PendingRequestExists();
    error NoPendingRequest();
    error ClaimableRequestExists();

    struct DepositQueueStorage {
        uint256 handledIndices;
        mapping(address account => Checkpoints.Checkpoint224) requestOf;
        FenwickTreeLibrary.Tree requests;
        Checkpoints.Trace224 prices;
    }

    // View functions

    function claimableOf(address account) external view returns (uint256);

    function requestOf(address account) external view returns (uint256 timestamp, uint256 assets);

    // Mutable functions

    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable;

    function cancelDepositRequest() external;

    function claim(address account) external returns (bool);

    // Events

    event DepositRequested(address indexed account, address indexed referral, uint224 assets, uint32 timestamp);
    event DepositRequestCanceled(address indexed account, uint256 assets, uint32 timestamp);
    event DepositRequestClaimed(address indexed account, uint256 shares, uint32 timestamp);
}
