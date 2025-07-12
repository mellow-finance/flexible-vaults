// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";
import "../modules/IShareModule.sol";

/// @title IOracle
/// @notice Interface for price oracle that handles report submission, validation, and state propagation to vault
interface IOracle is IFactoryEntity {
    /// @notice Thrown when an asset is not supported by the oracle
    error UnsupportedAsset(address asset);

    /// @notice Thrown when an asset is already supported
    error AlreadySupportedAsset(address asset);

    /// @notice Thrown when a suspicious report does not match expected data
    error InvalidReport();

    /// @notice Thrown when zero value is provided where non-zero is required
    error ZeroValue();

    /// @notice Thrown when a report is submitted too early relative to the timeout
    error TooEarly(uint256 timestamp, uint256 minTimestamp);

    /// @notice Thrown when submitted price is invalid according to oracle security rules
    error InvalidPrice(uint256 priceD18);

    /// @notice Thrown when the caller does not have the required permission
    error Forbidden();

    /// @notice Parameters that control oracle behavior and report validation
    struct SecurityParams {
        uint224 maxAbsoluteDeviation; // Max allowed absolute price deviation
        uint224 suspiciousAbsoluteDeviation; // Threshold for flagging absolute deviations as suspicious
        uint64 maxRelativeDeviationD18; // Max allowed relative deviation (in 1e18 format)
        uint64 suspiciousRelativeDeviationD18; // Threshold for flagging relative deviation as suspicious (in 1e18 format)
        uint32 timeout; // Minimum seconds between valid report updates
        uint32 depositInterval; // Lookback interval for eligible deposit timestamp
        uint32 redeemInterval; // Lookback interval for eligible redeem timestamp
    }

    /// @notice Price report struct
    /// @dev shares = price * assets / 1e18
    struct Report {
        address asset;
        uint224 priceD18; // price with 18 decimals
    }

    /// @notice Detailed price report used for validation and tracking
    struct DetailedReport {
        uint224 priceD18; // latest price
        uint32 timestamp; // when the price was submitted
        bool isSuspicious; // whether report is flagged as suspicious
    }

    /// @notice Storage layout of the oracle
    struct OracleStorage {
        IShareModule vault; // The vault module that integrates with oracle reports
        SecurityParams securityParams; // Oracle security configuration
        EnumerableSet.AddressSet supportedAssets; // List of supported assets
        mapping(address asset => DetailedReport) reports; // Latest report per asset
    }

    /// @notice Role required to submit reports
    function SUBMIT_REPORTS_ROLE() external view returns (bytes32);

    /// @notice Role required to accept suspicious reports
    function ACCEPT_REPORT_ROLE() external view returns (bytes32);

    /// @notice Role required to update security parameters
    function SET_SECURITY_PARAMS_ROLE() external view returns (bytes32);

    /// @notice Role required to add new supported assets
    function ADD_SUPPORTED_ASSETS_ROLE() external view returns (bytes32);

    /// @notice Role required to remove supported assets
    function REMOVE_SUPPORTED_ASSETS_ROLE() external view returns (bytes32);

    /// @notice Returns the connected vault module
    function vault() external view returns (IShareModule);

    /// @notice Returns current security parameters
    function securityParams() external view returns (SecurityParams memory);

    /// @notice Returns total count of supported assets
    function supportedAssets() external view returns (uint256);

    /// @notice Returns the supported asset at a specific index
    /// @param index Index in the supported asset set
    function supportedAssetAt(uint256 index) external view returns (address);

    /// @notice Checks whether an asset is supported
    /// @param asset Address of the asset
    function isSupportedAsset(address asset) external view returns (bool);

    /// @notice Returns the most recent detailed report for an asset
    /// @param asset Address of the asset
    function getReport(address asset) external view returns (DetailedReport memory);

    /// @notice Validates a price value for an asset based on configured thresholds
    /// @param priceD18 Price to validate (18 decimals)
    /// @param asset Address of the asset
    /// @return isValid Whether price is acceptable
    /// @return isSuspicious Whether price is flagged as suspicious
    function validatePrice(uint256 priceD18, address asset) external view returns (bool isValid, bool isSuspicious);

    /// @notice Submits one or more price reports
    /// @dev Callable only by account with `SUBMIT_REPORTS_ROLE`
    /// @param reports Array of price reports
    function submitReports(Report[] calldata reports) external;

    /// @notice Accepts a previously suspicious report
    /// @dev Callable only by account with `ACCEPT_REPORT_ROLE`
    /// @param asset Address of the asset
    /// @param priceD18 Submitted price
    /// @param timestamp Timestamp that must match existing suspicious report
    function acceptReport(address asset, uint256 priceD18, uint32 timestamp) external;

    /// @notice Updates oracle security parameters
    /// @param securityParams_ New security settings
    function setSecurityParams(SecurityParams calldata securityParams_) external;

    /// @notice Adds multiple new assets to the supported set
    /// @param assets Array of asset addresses to add
    function addSupportedAssets(address[] calldata assets) external;

    /// @notice Removes assets from the supported set
    /// @param assets Array of asset addresses to remove
    function removeSupportedAssets(address[] calldata assets) external;

    /// @notice Sets the associated vault
    /// @param vault_ Address of the vault module
    function setVault(address vault_) external;

    /// @notice Emitted when price reports are submitted
    event ReportsSubmitted(Report[] reports);

    /// @notice Emitted when a suspicious report is accepted
    event ReportAccepted(address indexed asset, uint224 indexed priceD18, uint32 indexed timestamp);

    /// @notice Emitted when new security parameters are set
    event SecurityParamsSet(SecurityParams securityParams);

    /// @notice Emitted when new assets are added
    event SupportedAssetsAdded(address[] assets);

    /// @notice Emitted when supported assets are removed
    event SupportedAssetsRemoved(address[] assets);

    /// @notice Emitted when vault is set
    event SetVault(address indexed vault);
}
