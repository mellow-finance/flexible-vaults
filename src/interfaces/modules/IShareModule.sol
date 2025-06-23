// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";
import "../hooks/IDepositHook.sol";
import "../hooks/IRedeemHook.sol";
import "../managers/IFeeManager.sol";
import "../managers/IShareManager.sol";
import "../oracles/IOracle.sol";
import "../queues/IDepositQueue.sol";
import "../queues/IQueue.sol";
import "../queues/IRedeemQueue.sol";
import "./IBaseModule.sol";

interface IShareModule is IBaseModule {
    struct ShareModuleStorage {
        address shareManager;
        address feeManager;
        address depositOracle;
        address redeemOracle;
        address defaultDepositHook;
        address defaultRedeemHook;
        mapping(address queue => address) customHooks;
        mapping(address queue => bool) isDepositQueue;
        mapping(address asset => EnumerableSet.AddressSet) queues;
        EnumerableSet.AddressSet assets;
    }

    // View functions

    function shareManager() external view returns (IShareManager);

    function feeManager() external view returns (IFeeManager);

    function depositOracle() external view returns (IOracle);

    function redeemOracle() external view returns (IOracle);

    function depositQueueFactory() external view returns (IFactory);

    function claimableSharesOf(address account) external view returns (uint256 shares);

    function redeemQueueFactory() external view returns (IFactory);

    function getAssetCount() external view returns (uint256);

    function assetAt(uint256 index) external view returns (address);

    function hasAsset(address asset) external view returns (bool);

    function hasQueue(address queue) external view returns (bool);

    function isDepositQueue(address queue) external view returns (bool);

    function getQueueCount(address asset) external view returns (uint256);

    function queueAt(address asset, uint256 index) external view returns (address);

    function getHook(address queue) external view returns (address hook);

    function getLiquidAssets() external view returns (uint256);

    function defaultDepositHook() external view returns (address);

    function defaultRedeemHook() external view returns (address);

    // Mutable functions

    function claimShares(address account) external;

    function setCustomHook(address queue, address hook) external;

    function createDepositQueue(uint256 version, address owner, address asset, bytes calldata data) external;

    function callRedeemHook(address asset, uint256 assets) external;

    function createRedeemQueue(uint256 version, address owner, address asset, bytes calldata data) external;

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external;
}
