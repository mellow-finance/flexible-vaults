// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../hooks/IDepositHook.sol";

import "../managers/ISharesManager.sol";
import "../oracles/IOracle.sol";
import "../queues/IQueue.sol";
import "./IBaseModule.sol";

interface ISharesModule is IBaseModule {
    struct SharesModuleStorage {
        address sharesManager;
        address depositOracle;
        address redeemOracle;
    }
    // View functions

    function sharesManager() external view returns (ISharesManager);

    function depositOracle() external view returns (IOracle);

    function redeemOracle() external view returns (IOracle);

    function getDepositQueues(address /* asset */ ) external view returns (address[] memory);

    function getRedeemQueues(address /* asset */ ) external view returns (address[] memory);

    // Mutable functions

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external;
}
