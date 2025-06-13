// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../modules/SharesModule.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Oracle is ContextUpgradeable {
    using Checkpoints for Checkpoints.Trace224;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct SecurityParams {
        uint208 maxAbsoluteDeviation;
        uint208 suspiciousAbsoluteDeviation;
        uint64 maxRelativeDeviationD18;
        uint64 suspiciousRelativeDeviationD18;
        uint32 timeout;
        uint32 secureInterval;
    }

    struct Report {
        address asset;
        uint208 priceD18;
    }

    struct DetailedReport {
        uint208 priceD18;
        uint32 timestamp;
        bool isSuspicious;
    }

    struct OracleStorage {
        SharesModule vault;
        SecurityParams securityParams;
        EnumerableSet.AddressSet supportedAssets;
        mapping(address asset => DetailedReport) reports;
    }

    bytes32 private immutable _oracleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _oracleStorageSlot = SlotLibrary.getSlot("Oracle", name_, version_);
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(IAccessControl(address(_oracleStorage().vault)).hasRole(role, _msgSender()), "Oracle: forbidden");
        _;
    }

    // Mutable functions

    function sendReport(Report[] calldata reports) external onlyRole(PermissionsLibrary.SEND_REPORT_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        SecurityParams memory securityParams = _oracleStorage().securityParams;
        uint48 secureTimestamp = uint48(block.timestamp - securityParams.secureInterval);
        for (uint256 i = 0; i < reports.length; i++) {
            if (!$.supportedAssets.contains(reports[i].asset)) {
                revert("Oracle: unsupported asset");
            }
            if (_handleReport(securityParams, reports[i].priceD18, $.reports[reports[i].asset])) {
                _handleReport(reports[i].asset, reports[i].priceD18, secureTimestamp);
            }
        }
    }

    function acceptReport(address asset, uint48 timestamp) external onlyRole(PermissionsLibrary.ACCEPT_REPORT_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        DetailedReport storage report_ = $.reports[asset];
        if (!report_.isSuspicious) {
            revert("Oracle: report is not suspicious");
        }
        if (report_.timestamp != timestamp) {
            revert("Oracle: report timestamp mismatch");
        }
        report_.isSuspicious = false;
        _handleReport(asset, report_.priceD18, timestamp - $.securityParams.secureInterval);
    }

    function setSecurityParams(SecurityParams calldata securityParams)
        external
        onlyRole(PermissionsLibrary.SET_SECURITY_PARAMS_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        if (securityParams.maxAbsoluteDeviation == 0 || securityParams.suspiciousAbsoluteDeviation == 0) {
            revert("Oracle: zero absolute deviation");
        }
        if (securityParams.maxRelativeDeviationD18 == 0 || securityParams.suspiciousRelativeDeviationD18 == 0) {
            revert("Oracle: zero relative deviation");
        }
        if (securityParams.timeout == 0 || securityParams.secureInterval == 0) {
            revert("Oracle: zero timeout or secure interval");
        }
        $.securityParams = securityParams;
    }

    function addSupportedAssets(address[] calldata assets)
        external
        onlyRole(PermissionsLibrary.ADD_SUPPORTED_ASSETS_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        for (uint256 i = 0; i < assets.length; i++) {
            if (!$.supportedAssets.add(assets[i])) {
                revert("Oracle: asset already supported");
            }
        }
    }

    function removeSupportedAssets(address[] calldata assets)
        external
        onlyRole(PermissionsLibrary.REMOVE_SUPPORTED_ASSETS_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        for (uint256 i = 0; i < assets.length; i++) {
            if (!$.supportedAssets.remove(assets[i])) {
                revert("Oracle: asset not supported");
            }
        }
    }

    // Internal functions

    function __Oracle_init(bytes calldata initParams) internal onlyInitializing {}

    function _handleReport(SecurityParams memory securityParams, uint208 priceD18, DetailedReport storage report)
        internal
        returns (bool)
    {
        if (priceD18 == 0) {
            revert("Oracle: zero price");
        }
        uint256 reportTimestamp = report.timestamp;
        if (reportTimestamp == 0) {
            // first report
            report.priceD18 = priceD18;
            report.timestamp = uint32(block.timestamp);
            report.isSuspicious = true;
            return false;
        }
        if (securityParams.timeout + reportTimestamp > block.timestamp) {
            revert("Oracle: too early to report");
        }

        uint256 reportPriceD18 = report.priceD18;

        bool isSuspicious = false;
        uint256 absoluteDeviation = priceD18 > reportPriceD18 ? priceD18 - reportPriceD18 : reportPriceD18 - priceD18;
        if (absoluteDeviation > securityParams.maxAbsoluteDeviation) {
            revert("Oracle: absolute deviation too high");
        }
        if (absoluteDeviation > securityParams.suspiciousAbsoluteDeviation) {
            isSuspicious = true;
        }

        uint256 relativeDeviationD18 = (absoluteDeviation * 1 ether) / reportPriceD18;
        if (relativeDeviationD18 > securityParams.maxRelativeDeviationD18) {
            revert("Oracle: relative deviation too high");
        }
        if (relativeDeviationD18 > securityParams.suspiciousRelativeDeviationD18) {
            isSuspicious = true;
        }

        report.priceD18 = priceD18;
        report.timestamp = uint32(block.timestamp);
        report.isSuspicious = isSuspicious;
        return !isSuspicious;
    }

    function _handleReport(address asset, uint208 priceD18, uint48 timestamp) internal {
        // TODO: implement
    }

    function _oracleStorage() internal view returns (OracleStorage storage $) {
        bytes32 slot = _oracleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
