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
    error UnsupportedAsset(address asset);
    error QueueLimitReached();
    error ZeroValue();

    struct ShareModuleStorage {
        address shareManager;
        address feeManager;
        address oracle;
        address defaultDepositHook;
        address defaultRedeemHook;
        uint256 queueCount;
        uint256 queueLimit;
        mapping(address queue => address) customHooks;
        mapping(address queue => bool) isDepositQueue;
        mapping(address queue => bool) isPausedQueue;
        mapping(address asset => EnumerableSet.AddressSet) queues;
        EnumerableSet.AddressSet assets;
    }

    // View functions

    function SET_HOOK_ROLE() external view returns (bytes32);
    function CREATE_QUEUE_ROLE() external view returns (bytes32);
    function PAUSE_QUEUE_ROLE() external view returns (bytes32);
    function UNPAUSE_QUEUE_ROLE() external view returns (bytes32);
    function SET_QUEUE_LIMIT_ROLE() external view returns (bytes32);
    function REMOVE_QUEUE_ROLE() external view returns (bytes32);

    function shareManager() external view returns (IShareManager);

    function feeManager() external view returns (IFeeManager);

    function oracle() external view returns (IOracle);

    function depositQueueFactory() external view returns (IFactory);

    function claimableSharesOf(address account) external view returns (uint256 shares);

    function redeemQueueFactory() external view returns (IFactory);

    function getAssetCount() external view returns (uint256);

    function assetAt(uint256 index) external view returns (address);

    function hasAsset(address asset) external view returns (bool);

    function hasQueue(address queue) external view returns (bool);

    function isDepositQueue(address queue) external view returns (bool);

    function getQueueCount(address asset) external view returns (uint256);

    function getQueueCount() external view returns (uint256);

    function queueAt(address asset, uint256 index) external view returns (address);

    function getHook(address queue) external view returns (address hook);

    function getLiquidAssets() external view returns (uint256);

    function defaultDepositHook() external view returns (address);

    function defaultRedeemHook() external view returns (address);

    function queueLimit() external view returns (uint256);

    function isPausedQueue(address queue) external view returns (bool);

    // Mutable functions

    function claimShares(address account) external;

    function setCustomHook(address queue, address hook) external;
    function setDefaultDepositHook(address hook) external;
    function setDefaultRedeemHook(address hook) external;

    function createQueue(uint256 version, bool isDepositQueue, address owner, address asset, bytes calldata data)
        external;

    function removeQueue(address queue) external;

    function setQueueLimit(uint256 limit) external;

    function pauseQueue(address queue) external;

    function unpauseQueue(address queue) external;

    function callHook(uint256 assets) external;

    function handleReport(
        address asset,
        uint224 priceD18,
        uint32 latestEligibleDepositTimestamp,
        uint32 latestEligibleRedeemTimestamp
    ) external;

    // Events

    event SharesClaimed(address indexed account);
    event CustomHookSet(address indexed queue, address indexed hook);
    event QueueCreated(address indexed queue, address indexed asset, bool isDepositQueue);
    event QueueRemoved(address indexed queue, address indexed asset);
    event HookCalled(address indexed queue, address indexed asset, uint256 assets, address hook);
    event QueueLimitSet(uint256 limit);
    event QueuePaused(address indexed queue);
    event QueueUnpaused(address indexed queue);
    event DefaultHookSet(address indexed hook, bool isDepositHook);
    event ReportHandled(
        address indexed asset,
        uint224 priceD18,
        uint32 latestEligibleDepositTimestamp,
        uint32 latestEligibleRedeemTimestamp,
        uint256 fees
    );
}
