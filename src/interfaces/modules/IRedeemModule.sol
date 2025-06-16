// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactory.sol";
import "../hooks/IRedeemHook.sol";
import "../queues/IRedeemQueue.sol";
import "./IACLModule.sol";
import "./ISharesModule.sol";

interface IRedeemModule {
    struct RedeemModuleStorage {
        address defaultHook;
        mapping(address queue => address) customHooks;
        mapping(address asset => EnumerableSet.AddressSet) queues;
        EnumerableSet.AddressSet assets;
    }

    // View functions

    function redeemQueueFactory() external view returns (address);

    function redeemAssets() external view returns (uint256);

    function redeemAssetAt(uint256 index) external view returns (address);

    function isRedeemAsset(address asset) external view returns (bool);

    function hasRedeemQueue(address queue) external view returns (bool);

    function getRedeemHook(address queue) external view returns (address hook);

    function getLiquidAssets(address asset) external view returns (uint256);

    // Mutable functions

    function setCustomRedeemHook(address queue, address hook) external;

    function callRedeemHook(address asset, uint256 assets) external;

    function createRedeemQueue(uint256 version, address owner, address asset, bytes32 salt) external;
}
