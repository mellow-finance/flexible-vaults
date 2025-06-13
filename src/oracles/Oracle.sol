// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../modules/SharesModule.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Oracle is ContextUpgradeable, ReentrancyGuardUpgradeable {
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

    function vault() public view returns (SharesModule) {
        return _oracleStorage().vault;
    }

    function securityParams() public view returns (SecurityParams memory) {
        return _oracleStorage().securityParams;
    }

    function supportedAssets() public view returns (address[] memory) {
        return _oracleStorage().supportedAssets.values();
    }

    function isSupportedAsset(address asset) public view returns (bool) {
        return _oracleStorage().supportedAssets.contains(asset);
    }

    function getReport(address asset) public view returns (DetailedReport memory) {
        OracleStorage storage $ = _oracleStorage();
        if (!$.supportedAssets.contains(asset)) {
            revert("Oracle: unsupported asset");
        }
        return $.reports[asset];
    }

    // Mutable functions

    function sendReport(Report[] calldata reports) external onlyRole(PermissionsLibrary.SEND_REPORT_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        SecurityParams memory securityParams_ = _oracleStorage().securityParams;
        uint48 secureTimestamp = uint48(block.timestamp - securityParams_.secureInterval);
        SharesModule vault_ = vault();
        for (uint256 i = 0; i < reports.length; i++) {
            if (!$.supportedAssets.contains(reports[i].asset)) {
                revert("Oracle: unsupported asset");
            }
            if (_handleReport(securityParams_, reports[i].priceD18, $.reports[reports[i].asset])) {
                vault_.handleReport(reports[i].asset, reports[i].priceD18, secureTimestamp);
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
        vault().handleReport(asset, report_.priceD18, timestamp - $.securityParams.secureInterval);
    }

    function setSecurityParams(SecurityParams calldata securityParams_)
        external
        onlyRole(PermissionsLibrary.SET_SECURITY_PARAMS_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        if (securityParams_.maxAbsoluteDeviation == 0 || securityParams_.suspiciousAbsoluteDeviation == 0) {
            revert("Oracle: zero absolute deviation");
        }
        if (securityParams_.maxRelativeDeviationD18 == 0 || securityParams_.suspiciousRelativeDeviationD18 == 0) {
            revert("Oracle: zero relative deviation");
        }
        if (securityParams_.timeout == 0 || securityParams_.secureInterval == 0) {
            revert("Oracle: zero timeout or secure interval");
        }
        $.securityParams = securityParams_;
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

    function __Oracle_init(bytes calldata initParams) internal onlyInitializing {
        __ReentrancyGuard_init();
        (address vault_, SecurityParams memory securityParams_, address[] memory assets_) =
            abi.decode(initParams, (address, SecurityParams, address[]));
        if (vault_ == address(0)) {
            revert("Oracle: zero vault address");
        }
        if (securityParams_.maxAbsoluteDeviation == 0 || securityParams_.suspiciousAbsoluteDeviation == 0) {
            revert("Oracle: zero absolute deviation");
        }
        if (securityParams_.maxRelativeDeviationD18 == 0 || securityParams_.suspiciousRelativeDeviationD18 == 0) {
            revert("Oracle: zero relative deviation");
        }
        if (securityParams_.timeout == 0 || securityParams_.secureInterval == 0) {
            revert("Oracle: zero timeout or secure interval");
        }
        OracleStorage storage $ = _oracleStorage();
        $.vault = SharesModule(payable(vault_));
        $.securityParams = securityParams_;
        for (uint256 i = 0; i < assets_.length; i++) {
            if (assets_[i] == address(0)) {
                revert("Oracle: zero asset address");
            }
            $.supportedAssets.add(assets_[i]);
        }
    }

    function _handleReport(SecurityParams memory securityParams_, uint208 priceD18, DetailedReport storage report)
        internal
        returns (bool)
    {
        if (priceD18 == 0) {
            revert("Oracle: zero price");
        }
        uint256 reportTimestamp = report.timestamp;
        if (reportTimestamp == 0) {
            report.priceD18 = priceD18;
            report.timestamp = uint32(block.timestamp);
            report.isSuspicious = true;
            return false;
        }
        if (securityParams_.timeout + reportTimestamp > block.timestamp) {
            revert("Oracle: too early to report");
        }

        uint256 reportPriceD18 = report.priceD18;
        bool isSuspicious = false;
        uint256 absoluteDeviation = priceD18 > reportPriceD18 ? priceD18 - reportPriceD18 : reportPriceD18 - priceD18;
        uint256 relativeDeviationD18 = (absoluteDeviation * 1 ether) / reportPriceD18;
        if (
            absoluteDeviation > securityParams_.maxAbsoluteDeviation
                || relativeDeviationD18 > securityParams_.maxRelativeDeviationD18
        ) {
            revert("Oracle: price deviation too high");
        }
        if (
            absoluteDeviation > securityParams_.suspiciousAbsoluteDeviation
                || relativeDeviationD18 > securityParams_.suspiciousRelativeDeviationD18
        ) {
            isSuspicious = true;
        }

        report.priceD18 = priceD18;
        report.timestamp = uint32(block.timestamp);
        report.isSuspicious = isSuspicious;
        return !isSuspicious;
    }

    function _oracleStorage() internal view returns (OracleStorage storage $) {
        bytes32 slot = _oracleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
