// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../factories/IFactoryEntity.sol";

import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";

interface ISyncQueue is IFactoryEntity {
    // Structs

    struct SyncQueueStorage {
        address vault;
        address asset;
        uint256 coefficient;
    }

    // Errors

    error ZeroValue();

    error QueuePaused();

    error InvalidReport();

    // View functions

    function name() external view returns (string memory);

    function vault() external view returns (address);

    function asset() external view returns (address);

    function canBeRemoved() external pure returns (bool);

    // Mutable functions

    function handleReport(uint224 priceD18, uint32 timestamp) external;
}
