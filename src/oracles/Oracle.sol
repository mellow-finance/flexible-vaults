// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/oracles/IOracle.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";

contract Oracle is IOracle, ContextUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _oracleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _oracleStorageSlot = SlotLibrary.getSlot("Oracle", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(IAccessControl(address(_oracleStorage().vault)).hasRole(role, _msgSender()), "Oracle: forbidden");
        _;
    }

    function vault() public view returns (IShareModule) {
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

    function validatePrice(uint256 priceD18, address asset) public view returns (bool isValid, bool isSuspicious) {
        OracleStorage storage $ = _oracleStorage();
        if (!$.supportedAssets.contains(asset)) {
            return (false, false);
        }
        return _validatePrice(priceD18, _oracleStorage().reports[asset]);
    }

    // Mutable functions

    function initialize(bytes calldata initParams) external initializer {
        __Oracle_init(initParams);
    }

    function submitReports(Report[] calldata reports) external onlyRole(PermissionsLibrary.SUBMIT_REPORT_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        SecurityParams memory securityParams_ = _oracleStorage().securityParams;
        uint32 secureTimestamp = uint32(block.timestamp - securityParams_.secureInterval);
        IShareModule vault_ = vault();
        for (uint256 i = 0; i < reports.length; i++) {
            if (!$.supportedAssets.contains(reports[i].asset)) {
                revert("Oracle: unsupported asset");
            }
            if (_handleReport(securityParams_, reports[i].priceD18, $.reports[reports[i].asset])) {
                vault_.handleReport(reports[i].asset, reports[i].priceD18, secureTimestamp);
            }
        }
    }

    function acceptReport(address asset, uint32 timestamp) external onlyRole(PermissionsLibrary.ACCEPT_REPORT_ROLE) {
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
        $.vault = IShareModule(vault_);
        $.securityParams = securityParams_;
        for (uint256 i = 0; i < assets_.length; i++) {
            if (assets_[i] == address(0)) {
                revert("Oracle: zero asset address");
            }
            $.supportedAssets.add(assets_[i]);
        }
    }

    function _handleReport(SecurityParams memory securityParams_, uint224 priceD18, DetailedReport storage report)
        internal
        returns (bool)
    {
        if (report.timestamp != 0 && securityParams_.timeout + report.timestamp > block.timestamp) {
            revert("Oracle: too early to report");
        }
        (bool isValid, bool isSuspicious) = _validatePrice(priceD18, report);
        if (!isValid) {
            revert("Oracle: invalid price");
        }
        report.priceD18 = priceD18;
        report.timestamp = uint32(block.timestamp);
        report.isSuspicious = isSuspicious;
        return !isSuspicious;
    }

    function _validatePrice(uint256 priceD18, DetailedReport storage report)
        private
        view
        returns (bool isValid, bool isSuspicious)
    {
        uint256 prevPriceD18 = report.priceD18;
        if (prevPriceD18 == 0) {
            return (true, true);
        }
        SecurityParams memory securityParams_ = _oracleStorage().securityParams;
        uint256 absoluteDeviation = priceD18 > prevPriceD18 ? priceD18 - prevPriceD18 : prevPriceD18 - priceD18;
        uint256 relativeDeviationD18 = Math.mulDiv(absoluteDeviation, 1 ether, prevPriceD18);
        if (
            absoluteDeviation > securityParams_.maxAbsoluteDeviation
                || relativeDeviationD18 > securityParams_.maxRelativeDeviationD18
        ) {
            return (false, false);
        }
        if (report.isSuspicious) {
            return (true, true);
        }
        if (
            absoluteDeviation > securityParams_.suspiciousAbsoluteDeviation
                || relativeDeviationD18 > securityParams_.suspiciousRelativeDeviationD18
        ) {
            return (true, true);
        }
        return (true, false);
    }

    function _oracleStorage() internal view returns (OracleStorage storage $) {
        bytes32 slot = _oracleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
