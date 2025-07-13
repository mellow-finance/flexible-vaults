// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactory.sol";
import "../hooks/IRedeemHook.sol";
import "../managers/IFeeManager.sol";
import "../managers/IShareManager.sol";
import "../oracles/IOracle.sol";
import "../queues/IDepositQueue.sol";
import "../queues/IQueue.sol";
import "../queues/IRedeemQueue.sol";
import "./IBaseModule.sol";

/// @title IShareModule
/// @notice Manages user-facing interactions with the vault via deposit/redeem queues, hooks, and share accounting.
/// @dev Coordinates oracle report handling, hook invocation, fee calculation, and queue lifecycle.
interface IShareModule is IBaseModule {
    /// @notice Thrown when an unsupported asset is used for queue creation.
    error UnsupportedAsset(address asset);

    /// @notice Thrown when the number of queues exceeds the allowed system-wide maximum.
    error QueueLimitReached();

    /// @notice Thrown when an operation is attempted with a zero-value parameter.
    error ZeroValue();

    /// @dev Storage structure for the ShareModule.
    struct ShareModuleStorage {
        address shareManager; // Address of the ShareManager responsible for minting/burning shares
        address feeManager; // Address of the FeeManager that calculates and collects protocol fees
        address oracle; // Address of the Oracle
        address defaultDepositHook; // Optional hook that is called by default after DepositQueue requests are processed
        address defaultRedeemHook; // Optional hook that is called by default before RedeemQueue requests are processed
        uint256 queueCount; // Total number of queues across all assets
        uint256 queueLimit; // Maximum number of queues allowed in the system
        mapping(address => address) customHooks; // Optional queue-specific hooks
        mapping(address => bool) isDepositQueue; // Whether the queue is a deposit queue
        mapping(address => bool) isPausedQueue; // Whether queue operations are currently paused
        mapping(address => EnumerableSet.AddressSet) queues; // Mapping of asset to its associated queues
        EnumerableSet.AddressSet assets; // Set of all supported assets with queues
    }

    /// @notice Role identifier for managing per-queue and default hooks
    function SET_HOOK_ROLE() external view returns (bytes32);

    /// @notice Role identifier for creating new queues
    function CREATE_QUEUE_ROLE() external view returns (bytes32);

    /// @notice Role identifier for changing the active/paused status of queues
    function SET_QUEUE_STATUS_ROLE() external view returns (bytes32);

    /// @notice Role identifier for modifying the global queue limit
    function SET_QUEUE_LIMIT_ROLE() external view returns (bytes32);

    /// @notice Role identifier for removing existing queues
    function REMOVE_QUEUE_ROLE() external view returns (bytes32);

    /// @notice Returns the ShareManager used for minting and burning shares
    function shareManager() external view returns (IShareManager);

    /// @notice Returns the FeeManager contract used for fee calculations
    function feeManager() external view returns (IFeeManager);

    /// @notice Returns the Oracle contract used for handling reports and managing supported assets.
    function oracle() external view returns (IOracle);

    /// @notice Returns the factory used for deploying deposit queues
    function depositQueueFactory() external view returns (IFactory);

    /// @notice Returns the factory used for deploying redeem queues
    function redeemQueueFactory() external view returns (IFactory);

    /// @notice Returns total number of distinct assets with queues
    function getAssetCount() external view returns (uint256);

    /// @notice Returns the address of the asset at the given index
    function assetAt(uint256 index) external view returns (address);

    /// @notice Returns whether the given asset is associated with any queues
    function hasAsset(address asset) external view returns (bool);

    /// @notice Returns whether the given queue is registered
    function hasQueue(address queue) external view returns (bool);

    /// @notice Returns whether the given queue is a deposit queue
    function isDepositQueue(address queue) external view returns (bool);

    /// @notice Returns whether the given queue is currently paused
    function isPausedQueue(address queue) external view returns (bool);

    /// @notice Returns number of queues associated with a given asset
    function getQueueCount(address asset) external view returns (uint256);

    /// @notice Returns the total number of queues across all assets
    function getQueueCount() external view returns (uint256);

    /// @notice Returns the queue at the given index for the specified asset
    function queueAt(address asset, uint256 index) external view returns (address);

    /// @notice Returns the hook assigned to a queue (customHook or defaultHook as a fallback)
    function getHook(address queue) external view returns (address hook);

    /// @notice Returns the default hook for deposit queues
    function defaultDepositHook() external view returns (address);

    /// @notice Returns the default hook for redeem queues
    function defaultRedeemHook() external view returns (address);

    /// @notice Returns the current global queue limit
    function queueLimit() external view returns (uint256);

    /// @notice Returns the total number of claimable shares for a given user
    function claimableSharesOf(address account) external view returns (uint256 shares);

    /// @notice Called by redeem queues to check the amount of assets available for instant withdrawal
    function getLiquidAssets() external view returns (uint256);

    /// @notice Claims all claimable shares from deposit queues for the specified account
    function claimShares(address account) external;

    /// @notice Assigns a custom hook contract to a specific queue
    function setCustomHook(address queue, address hook) external;

    /// @notice Sets the global default deposit hook
    function setDefaultDepositHook(address hook) external;

    /// @notice Sets the global default redeem hook
    function setDefaultRedeemHook(address hook) external;

    /// @notice Creates a new deposit or redeem queue for a given asset
    function createQueue(uint256 version, bool isDepositQueue, address owner, address asset, bytes calldata data)
        external;

    /// @notice Removes a queue from the system if its `canBeRemoved()` function returns true
    function removeQueue(address queue) external;

    /// @notice Sets the maximum number of allowed queues across the module
    function setQueueLimit(uint256 limit) external;

    /// @notice Pauses or resumes a queue's operation
    function setQueueStatus(address queue, bool isPaused) external;

    /// @notice Invokes a queue's hook (also transfers assets to the queue for redeem queues)
    function callHook(uint256 assets) external;

    /// @notice Handles an oracle price report, distributes fees and calls internal hooks
    function handleReport(address asset, uint224 priceD18, uint32 depositTimestamp, uint32 redeemTimestamp) external;

    /// @notice Emitted when a user successfully claims shares from deposit queues
    event SharesClaimed(address indexed account);

    /// @notice Emitted when a queue-specific custom hook is updated
    event CustomHookSet(address indexed queue, address indexed hook);

    /// @notice Emitted when a new queue is created
    event QueueCreated(address indexed queue, address indexed asset, bool isDepositQueue);

    /// @notice Emitted when a queue is removed
    event QueueRemoved(address indexed queue, address indexed asset);

    /// @notice Emitted after a queue hook is successfully called
    event HookCalled(address indexed queue, address indexed asset, uint256 assets, address hook);

    /// @notice Emitted when the global queue limit is updated
    event QueueLimitSet(uint256 limit);

    /// @notice Emitted when a queue's paused status changes
    event SetQueueStatus(address indexed queue, bool indexed isPaused);

    /// @notice Emitted when a new default hook is configured
    event DefaultHookSet(address indexed hook, bool isDepositHook);

    /// @notice Emitted after processing a price report and fee distribution
    event ReportHandled(
        address indexed asset, uint224 indexed priceD18, uint32 depositTimestamp, uint32 redeemTimestamp, uint256 fees
    );
}
