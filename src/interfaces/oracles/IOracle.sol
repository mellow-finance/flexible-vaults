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
/// @notice Interface for the vault price oracle responsible for submitting, validating, and propagating price reports.
/// @dev The reported price is structured such that the invariant `shares = assets * price` holds true.
/// @dev Typically used to coordinate deposit, redemption and limit operations across queues, the vault and subvaults.
interface IOracle is IFactoryEntity {
    /// @notice Thrown when an asset is not supported by the oracle.
    /// @param asset The address of the unsupported asset.
    error UnsupportedAsset(address asset);

    /// @notice Thrown when attempting to register an asset that is already supported.
    /// @param asset The address of the already supported asset.
    error AlreadySupportedAsset(address asset);

    /// @notice Thrown when a suspicious report fails validation due to unexpected data.
    /// @dev This includes mismatches in price, timestamp, or incorrect `isSuspicios` flag.
    error InvalidReport();

    /// @notice Thrown when a function receives a zero value where a non-zero value is required.
    error ZeroValue();

    /// @notice Thrown when a report is submitted before the required timeout period,
    ///         and the previous report was not marked as suspicious.
    /// @param timestamp The submitted report timestamp.
    /// @param minTimestamp The earliest acceptable timestamp based on timeout configuration.
    error TooEarly(uint256 timestamp, uint256 minTimestamp);

    /// @notice Thrown when the submitted price violates oracle security rules.
    /// @param priceD18 The submitted price in 18-decimal fixed-point format.
    error InvalidPrice(uint256 priceD18);

    /// @notice Thrown when the caller lacks the necessary permission to perform the operation.
    error Forbidden();

    /// @notice Configuration parameters that govern oracle price validation logic and reporting cadence.
    struct SecurityParams {
        /// @notice Maximum absolute difference between the new and previous price, beyond which the report is rejected.
        uint224 maxAbsoluteDeviation;
        /// @notice Absolute deviation threshold beyond which the report is flagged as suspicious (but not rejected).
        uint224 suspiciousAbsoluteDeviation;
        /// @notice Maximum allowed relative price deviation (as a fixed-point value with 18 decimals), beyond which the report is rejected.
        ///         Example: 0.05 * 1e18 = 5% max relative deviation.
        uint64 maxRelativeDeviationD18;
        /// @notice Relative deviation threshold for flagging suspicious reports (in 18-decimal format),
        ///         beyond which the report is flagged as suspicious (but not rejected).
        ///         Example: 0.03 * 1e18 = 3% suspicious threshold.
        uint64 suspiciousRelativeDeviationD18;
        /// @notice Minimum time in seconds required between two valid non-suspicious reports.
        uint32 timeout;
        /// @notice Minimum age (in seconds) a deposit request must have to be eligible for processing by a report submitted at the current timestamp.
        uint32 depositInterval;
        /// @notice Minimum age (in seconds) a redemption request must have to be eligible for processing by a report submitted at the current timestamp.
        uint32 redeemInterval;
    }

    /// @notice Struct representing a price report submitted to the oracle.
    /// @dev Used in vault accounting where `shares = (assets * priceD18) / 1e18`.
    struct Report {
        address asset; // Address of the asset the price refers to
        uint224 priceD18; // Asset price in 18-decimal fixed-point format
    }

    /// @notice Detailed price report used for validation and tracking
    struct DetailedReport {
        uint224 priceD18; // Reported asset price in 18-decimal fixed-point format
        uint32 timestamp; // Timestamp when the report was submitted
        bool isSuspicious; // Whether the report is flagged as suspicious according to deviation thresholds
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

    /// @notice Validates the given price for a specific asset based on oracle security parameters.
    /// @dev Evaluates both absolute and relative deviation limits to determine whether the price is valid or suspicious.
    /// @param priceD18 Price to validate, in 18-decimal fixed-point format.
    /// @param asset Address of the asset being evaluated.
    /// @return isValid True if the price is within maximum allowed deviation.
    /// @return isSuspicious True if the price exceeds the suspicious deviation threshold.
    function validatePrice(uint256 priceD18, address asset) external view returns (bool isValid, bool isSuspicious);

    /// @notice Submits price reports for supported assets.
    /// @dev Processes pending deposit and redemption requests across DepositQueue and RedeemQueue contracts.
    ///      The core processing logic is determined by the ShareModule and Queue contracts.
    ///      Only callable by accounts with the `SUBMIT_REPORTS_ROLE`.
    /// @param reports An array of price reports, each specifying the target asset and its latest price (in 18 decimals).
    ///
    /// @dev Note: Submitted prices MUST reflect protocol and performance fee deductions, ensuring accurate share issuance.
    function submitReports(Report[] calldata reports) external;

    /// @notice Accepts a previously suspicious report
    /// @dev Callable only by account with `ACCEPT_REPORT_ROLE`
    /// @param asset Address of the asset
    /// @param priceD18 Timestamp that must match existing suspicious report
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
