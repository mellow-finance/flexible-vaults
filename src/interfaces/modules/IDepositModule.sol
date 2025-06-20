// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactory.sol";
import "../hooks/IDepositHook.sol";
import "../queues/IDepositQueue.sol";
import "./IACLModule.sol";
import "./ISharesModule.sol";

interface IDepositModule {
    struct DepositModuleStorage {
        address defaultHook;
        mapping(address queue => address) customHooks;
        mapping(address asset => EnumerableSet.AddressSet) queues;
        EnumerableSet.AddressSet assets;
    }

    // View functions

    function depositQueueFactory() external view returns (address);

    function depositAssets() external view returns (uint256);

    function depositAssetAt(uint256 index) external view returns (address);

    function isDepositAsset(address asset) external view returns (bool);

    function hasDepositQueue(address queue) external view returns (bool);

    function depositQueues(address asset) external view returns (uint256);

    function depositQueueAt(address asset, uint256 index) external view returns (address);

    function claimableSharesOf(address account) external view returns (uint256 shares);

    function getDepositHook(address queue) external view returns (address hook);

    // Mutable functions

    function claimShares(address account) external;

    function setCustomDepositHook(address queue, address hook) external;

    function createDepositQueue(uint256 version, address owner, address asset, bytes calldata data) external;
}
