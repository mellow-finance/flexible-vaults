// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import "../../libraries/FenwickTreeLibrary.sol";
import "../factories/IFactoryEntity.sol";
import "../modules/IDepositModule.sol";
import "./IQueue.sol";

interface IDepositQueue is IQueue, IFactoryEntity {
    struct DepositQueueStorage {
        uint256 handledIndices;
        mapping(address account => Checkpoints.Checkpoint208) requestOf;
        FenwickTreeLibrary.Tree requests;
        Checkpoints.Trace208 prices;
    }

    // View functions

    function claimableOf(address account) external view returns (uint256);

    function requestOf(address account) external view returns (uint256 timestamp, uint256 assets);

    // Mutable functions

    function initialize(bytes calldata data) external;

    function deposit(uint208 assets, bytes32[] calldata merkleProof) external payable;

    function cancelDepositRequest() external;

    function claim(address account) external returns (bool);
}
