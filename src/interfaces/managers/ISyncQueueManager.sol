// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

interface ISyncQueueManager is IFactoryEntity {
    function getMultiplierD18() external view returns (uint256);
}
