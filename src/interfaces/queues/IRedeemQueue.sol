// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "../modules/IVaultModule.sol";
import "./IQueue.sol";

interface IRedeemQueue is IQueue {
    struct Request {
        uint256 timestamp;
        uint256 shares;
        bool isClaimable;
        uint256 assets;
    }

    struct Pair {
        uint256 assets;
        uint256 shares;
    }

    struct RedeemQueueStorage {
        uint256 handledIndices;
        uint256 outflowDemandIterator;
        uint256 fullDemand;
        mapping(address account => EnumerableMap.UintToUintMap) requestsOf;
        mapping(uint256 index => uint256 cumulativeShares) prefixSum;
        Pair[] outflowDemand;
        Checkpoints.Trace224 prices;
    }

    // View functions

    function requestsOf(address account, uint256 offset, uint256 limit)
        external
        view
        returns (Request[] memory requests);

    // Mutable functions

    function getDemand() external view returns (uint256 assets, uint256 shares);

    function redeem(uint256 shares) external;

    function claim(address account, uint256[] calldata timestamps) external returns (uint256 assets);

    function handleReports(uint256 reports) external returns (uint256 counter);

    /// Events

    event RedeemRequested(address indexed account, uint256 shares, uint256 timestamp);
    event RedeemRequestClaimed(address indexed account, address indexed receiver, uint256 assets, uint256[] timestamps);
    event RedeemRequestsHandled(uint256 counter, uint256 demand);
}
