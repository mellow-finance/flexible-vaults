// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IRedeemQueue} from "../interfaces/queues/IRedeemQueue.sol";
import "./OracleSubmitter.sol";

contract AutomatedReporter is AccessControlEnumerable {
    bytes32 public constant SUBMIT_ROLE = keccak256("oracles.AutomatedReporter.SUBMIT_ROLE");

    OracleSubmitter public immutable oracleSubmitter;

    constructor(OracleSubmitter oracleSubmitter_, address[] memory submitters) {
        address admin = oracleSubmitter.getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < submitters.length; i++) {
            _grantRole(SUBMIT_ROLE, submitters[i]);
        }
        oracleSubmitter = oracleSubmitter_;
    }

    function submit() external onlyRole(SUBMIT_ROLE) {
        IOracle oracle = oracleSubmitter.oracle();
        uint256 assets = oracle.supportedAssets();
        IOracle.Report[] memory reports = new IOracle.Report[](assets);
        for (uint256 i = 0; i < assets; i++) {
            address asset = oracle.supportedAssetAt(i);
            reports[i] = IOracle.Report(asset, oracle.getReport(asset).priceD18);
        }
        oracleSubmitter.submitReports(reports);
        IShareModule vault = oracle.vault();
        for (uint256 i = 0; i < assets; i++) {
            address asset = reports[i].asset;
            uint256 queues = vault.getQueueCount(asset);
            for (uint256 j = 0; j < queues; j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    continue;
                }
                IRedeemQueue(queue).handleBatches(type(uint256).max);
            }
        }
    }
}
