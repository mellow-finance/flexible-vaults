// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../modules/IVaultModule.sol";
import "./IQueue.sol";

/// @title IRedeemQueue
/// @notice Interface for redeem queues that manage time-delayed share redemptions.
/// @dev Handles redemption requests, pricing via oracle reports, and batch claim processing.
interface IRedeemQueue is IQueue {
    /// @notice Redemption request data structure.
    struct Request {
        uint256 timestamp;
        /// Time of the redemption request.
        uint256 shares;
        /// Amount of shares requested for redemption.
        bool isClaimable;
        /// Whether the redemption can currently be claimed.
        uint256 assets;
    }
    /// Amount of assets (tokens) available for claiming.

    /// @notice Redemption batch with matched shares and corresponding assets.
    struct Pair {
        uint256 assets;
        /// Total value of assets for this redemption batch.
        uint256 shares;
    }
    /// Total shares redeemable for this batch.

    /// @notice Internal storage layout for redeem queue implementations.
    struct RedeemQueueStorage {
        uint256 handledIndices;
        /// Index up to which batches have been processed.
        uint256 outflowDemandIterator;
        /// Index for processing batches from outflowDemand.
        uint256 fullDemand;
        /// Total outstanding redemption demand (in assets).
        mapping(address => EnumerableMap.UintToUintMap) requestsOf;
        /// User redemption requests (timestamp => shares).
        mapping(uint256 => uint256) prefixSum;
        /// Running sum of shares per batch index.
        Pair[] outflowDemand;
        /// Batched demand ready for redemption fulfillment.
        Checkpoints.Trace224 prices;
    }
    /// Oracle price reports and timestamps.

    /// @notice Returns paginated redemption requests for a user.
    /// @param account Address of the user.
    /// @param offset Index to start pagination from.
    /// @param limit Maximum number of requests to return.
    /// @return requests List of redemption requests (claimable and pending).
    function requestsOf(address account, uint256 offset, uint256 limit)
        external
        view
        returns (Request[] memory requests);

    /// @notice Returns the total asset and share demand from queued redemptions.
    /// @return assets Total asset demand.
    /// @return shares Total share supply matched to this demand.
    function getDemand() external view returns (uint256 assets, uint256 shares);

    /// @notice Initiates a new redemption by queuing shares for future asset claims.
    /// @param shares Amount of shares to redeem.
    function redeem(uint256 shares) external;

    /// @notice Claims previously processed redemptions using the provided timestamps.
    /// @param account Address of the user claiming.
    /// @param timestamps List of timestamps associated with processed redemption requests.
    /// @return assets Total amount of assets claimed.
    function claim(address account, uint32[] calldata timestamps) external returns (uint256 assets);

    /// @notice Processes oracle price reports and matches them against queued redemptions.
    /// @param reports Maximum number of price reports to process in one call.
    /// @return counter Number of processed redemption batches.
    function handleReports(uint256 reports) external returns (uint256 counter);

    /// @notice Emitted when a new redemption request is made.
    /// @param account Address of the redeemer.
    /// @param shares Amount of shares redeemed.
    /// @param timestamp Timestamp of the request.
    event RedeemRequested(address indexed account, uint256 shares, uint256 timestamp);

    /// @notice Emitted when redemption is claimed by a user.
    /// @param account Address of the redeemer.
    /// @param receiver Address receiving the assets.
    /// @param assets Amount of assets claimed.
    /// @param timestamps Timestamps of the claimed redemption requests.
    event RedeemRequestClaimed(address indexed account, address indexed receiver, uint256 assets, uint32[] timestamps);

    /// @notice Emitted when oracle price reports are processed and redemptions are fulfilled.
    /// @param counter Number of processed batches.
    /// @param demand Total assets fulfilled in the processed redemptions.
    event RedeemRequestsHandled(uint256 counter, uint256 demand);
}
