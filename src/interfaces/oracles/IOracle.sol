// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";
import "../modules/IShareModule.sol";

interface IOracle is IFactoryEntity {
    error UnsupportedAsset(address asset);
    error AlreadySupportedAsset(address asset);
    error NonSuspiciousReport(address asset, uint256 timestamp);
    error InvalidTimestamp(uint256 timestamp, uint256 expectedTimestamp);
    error ZeroValue();
    error TooEarly(uint256 timestamp, uint256 minTimestamp);
    error InvalidPrice(uint256 priceD18);

    struct SecurityParams {
        uint224 maxAbsoluteDeviation;
        uint224 suspiciousAbsoluteDeviation;
        uint64 maxRelativeDeviationD18;
        uint64 suspiciousRelativeDeviationD18;
        uint32 timeout;
        uint32 secureInterval;
    }

    /// @dev shares = price18 * assets / 1e18
    struct Report {
        address asset;
        uint224 priceD18;
    }

    struct DetailedReport {
        uint224 priceD18;
        uint32 timestamp;
        bool isSuspicious;
    }

    struct OracleStorage {
        IShareModule vault;
        SecurityParams securityParams;
        EnumerableSet.AddressSet supportedAssets;
        mapping(address asset => DetailedReport) reports;
    }

    function SUBMIT_REPORTS_ROLE() external view returns (bytes32);
    function ACCEPT_REPORT_ROLE() external view returns (bytes32);
    function SET_SECURITY_PARAMS_ROLE() external view returns (bytes32);
    function ADD_SUPPORTED_ASSETS_ROLE() external view returns (bytes32);
    function REMOVE_SUPPORTED_ASSETS_ROLE() external view returns (bytes32);

    function vault() external view returns (IShareModule);
    function securityParams() external view returns (SecurityParams memory);
    function supportedAssets() external view returns (uint256);
    function supportedAssetAt(uint256 index) external view returns (address);
    function isSupportedAsset(address asset) external view returns (bool);
    function getReport(address asset) external view returns (DetailedReport memory);
    function validatePrice(uint256 priceD18, address asset) external view returns (bool isValid, bool isSuspicious);
    function submitReports(Report[] calldata reports) external;
    function acceptReport(address asset, uint32 timestamp) external;
    function setSecurityParams(SecurityParams calldata securityParams_) external;
    function addSupportedAssets(address[] calldata assets) external;
    function removeSupportedAssets(address[] calldata assets) external;
    function setVault(address vault_) external;

    // Events

    event ReportsSubmitted(Report[] reports);
    event ReportAccepted(address indexed asset, uint224 indexed priceD18, uint32 indexed timestamp);
    event SecurityParamsSet(SecurityParams securityParams);
    event SupportedAssetsAdded(address[] assets);
    event SupportedAssetsRemoved(address[] assets);
    event SetVault(address indexed vault);
}
