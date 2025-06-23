// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../hooks/IDepositHook.sol";

import "../managers/IFeeManager.sol";
import "../managers/IShareManager.sol";
import "../oracles/IOracle.sol";
import "../queues/IQueue.sol";
import "./IBaseModule.sol";

interface IShareModule is IBaseModule {
    struct ShareModuleStorage {
        address shareManager;
        address feeManager;
        address depositOracle;
        address redeemOracle;
    }

    // View functions

    function shareManager() external view returns (IShareManager);

    function feeManager() external view returns (IFeeManager);

    function depositOracle() external view returns (IOracle);

    function redeemOracle() external view returns (IOracle);

    function getDepositQueues(address /* asset */ ) external view returns (address[] memory);

    function getRedeemQueues(address /* asset */ ) external view returns (address[] memory);

    // Mutable functions

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external;
}
