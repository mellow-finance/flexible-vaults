// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

interface IQueue is IFactoryEntity {
    error ValueZero();
    error Forbidden();
    error InvalidReport();
    error QueuePaused();

    struct QueueStorage {
        address asset;
        address vault;
        Checkpoints.Trace224 timestamps;
    }

    // View functions

    function vault() external view returns (address);

    function asset() external view returns (address);

    function canBeRemoved() external view returns (bool);

    // Mutable functions

    function handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) external;
}
