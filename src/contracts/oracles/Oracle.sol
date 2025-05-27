// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/SharesModule.sol";

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

contract Oracle {
    using Checkpoints for Checkpoints.Trace224;

    bytes32 public constant ORACLE_REPORT_PRICES_ROLE = keccak256("ORACLE_REPORT_PRICES_ROLE");

    struct OracleStorage {
        SharesModule vault;
        uint256 timeout;
        uint256 maxAbsoluteDeviation;
        uint256 maxRelativeDeviation;
        uint32 depositSecureT;
        uint32 redeemSecureT;
        mapping(address asset => Checkpoints.Trace224) depositPriceReports;
        mapping(address asset => Checkpoints.Trace224) redeemPriceReports;
    }

    SharesModule public vault;
    uint256 public timeout;
    uint256 public maxAbsoluteDeviation;
    uint256 public maxRelativeDeviation;

    uint32 public depositSecureT = 1 days;
    uint32 public redeemSecureT = 14 days;

    mapping(address asset => Checkpoints.Trace224) private _depositPriceReports;
    mapping(address asset => Checkpoints.Trace224) private _redeemPriceReports;

    struct Report {
        address asset;
        uint224 depositPriceD18; // assets * price = shares
        uint224 redeemPriceD18; // shares * price = assets
    }

    /*
        TODO add:
            1. max relative deviation
            2. max absolute deviation
            3. timeout between reports
    */

    function reportPrices(Report[] calldata reports) external {
        require(
            IAccessControl(address(vault)).hasRole(ORACLE_REPORT_PRICES_ROLE, msg.sender),
            "Oracle: forbidden"
        );
        // TODO: add sanity checks
        uint32 timestamp = uint32(block.timestamp);
        for (uint256 i = 0; i < reports.length; i++) {
            Report calldata report = reports[i];
            if (report.depositPriceD18 != 0) {
                _depositPriceReports[report.asset].push(timestamp, report.depositPriceD18);
            }
            if (report.redeemPriceD18 != 0) {
                _redeemPriceReports[report.asset].push(timestamp, report.redeemPriceD18);
            }
        }
    }

    function getDepositEpochPrice(address asset, uint256 epoch)
        public
        view
        returns (bool exists, uint224 priceD18)
    {
        uint256 timestamp = vault.endTimestampOf(epoch) + depositSecureT;
        if (timestamp > type(uint32).max) {
            return (false, 0);
        }
        priceD18 = _depositPriceReports[asset].lowerLookup(uint32(timestamp));
        exists = priceD18 != 0;
    }

    function getRedeemEpochPrice(address asset, uint256 epoch)
        public
        view
        returns (bool exists, uint224 priceD18)
    {
        uint256 timestamp = vault.endTimestampOf(epoch) + redeemSecureT;
        if (timestamp > type(uint32).max) {
            return (false, 0);
        }
        priceD18 = _redeemPriceReports[asset].lowerLookup(uint32(timestamp));
        exists = priceD18 != 0;
    }
}
