// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/oracles/IOracle.sol";

import "../libraries/SlotLibrary.sol";

contract Oracle is IOracle, ContextUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IOracle
    bytes32 public constant SUBMIT_REPORTS_ROLE = keccak256("oracles.Oracle.SUBMIT_REPORTS_ROLE");
    /// @inheritdoc IOracle
    bytes32 public constant ACCEPT_REPORT_ROLE = keccak256("oracles.Oracle.ACCEPT_REPORT_ROLE");
    /// @inheritdoc IOracle
    bytes32 public constant SET_SECURITY_PARAMS_ROLE = keccak256("oracles.Oracle.SET_SECURITY_PARAMS_ROLE");
    /// @inheritdoc IOracle
    bytes32 public constant ADD_SUPPORTED_ASSETS_ROLE = keccak256("oracles.Oracle.ADD_SUPPORTED_ASSETS_ROLE");
    /// @inheritdoc IOracle
    bytes32 public constant REMOVE_SUPPORTED_ASSETS_ROLE = keccak256("oracles.Oracle.REMOVE_SUPPORTED_ASSETS_ROLE");

    bytes32 private immutable _oracleStorageSlot;

    modifier onlyRole(bytes32 role) {
        if (!IAccessControl(address(_oracleStorage().vault)).hasRole(role, _msgSender())) {
            revert Forbidden();
        }
        _;
    }

    constructor(string memory name_, uint256 version_) {
        _oracleStorageSlot = SlotLibrary.getSlot("Oracle", name_, version_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc IOracle
    function vault() public view returns (IShareModule) {
        return _oracleStorage().vault;
    }

    /// @inheritdoc IOracle
    function securityParams() public view returns (SecurityParams memory) {
        return _oracleStorage().securityParams;
    }

    /// @inheritdoc IOracle
    function supportedAssets() public view returns (uint256) {
        return _oracleStorage().supportedAssets.length();
    }

    /// @inheritdoc IOracle
    function supportedAssetAt(uint256 index) public view returns (address) {
        return _oracleStorage().supportedAssets.at(index);
    }

    /// @inheritdoc IOracle
    function isSupportedAsset(address asset) public view returns (bool) {
        return _oracleStorage().supportedAssets.contains(asset);
    }

    /// @inheritdoc IOracle
    function getReport(address asset) public view returns (DetailedReport memory) {
        OracleStorage storage $ = _oracleStorage();
        if (!$.supportedAssets.contains(asset)) {
            revert UnsupportedAsset(asset);
        }
        return $.reports[asset];
    }

    /// @inheritdoc IOracle
    function validatePrice(uint256 priceD18, address asset) public view returns (bool isValid, bool isSuspicious) {
        OracleStorage storage $ = _oracleStorage();
        if (!$.supportedAssets.contains(asset)) {
            return (false, false);
        }
        return _validatePrice(priceD18, $.reports[asset], $.securityParams);
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata initParams) external initializer {
        __Oracle_init(initParams);
        emit Initialized(initParams);
    }

    /// @inheritdoc IOracle
    function setVault(address vault_) external {
        if (vault_ == address(0)) {
            revert ZeroValue();
        }
        OracleStorage storage $ = _oracleStorage();
        if (address($.vault) != address(0)) {
            revert InvalidInitialization();
        }
        $.vault = IShareModule(vault_);
        emit SetVault(vault_);
    }

    /// @inheritdoc IOracle
    function submitReports(Report[] calldata reports) external nonReentrant onlyRole(SUBMIT_REPORTS_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        SecurityParams memory securityParams_ = $.securityParams;
        uint32 depositTimestamp = uint32(block.timestamp - securityParams_.depositInterval);
        uint32 redeemTimestamp = uint32(block.timestamp - securityParams_.redeemInterval);
        IShareModule vault_ = $.vault;
        EnumerableSet.AddressSet storage supportedAssets_ = $.supportedAssets;
        mapping(address asset => DetailedReport) storage reports_ = $.reports;
        for (uint256 i = 0; i < reports.length; i++) {
            Report calldata report = reports[i];
            if (!supportedAssets_.contains(report.asset)) {
                revert UnsupportedAsset(report.asset);
            }
            if (_handleReport(securityParams_, report.priceD18, reports_[report.asset])) {
                vault_.handleReport(report.asset, report.priceD18, depositTimestamp, redeemTimestamp);
            }
        }
        emit ReportsSubmitted(reports);
    }

    /// @inheritdoc IOracle
    function acceptReport(address asset, uint256 priceD18, uint32 timestamp)
        external
        nonReentrant
        onlyRole(ACCEPT_REPORT_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        DetailedReport storage report_ = $.reports[asset];
        if (!report_.isSuspicious || report_.priceD18 != priceD18 || report_.timestamp != timestamp) {
            revert InvalidReport();
        }
        report_.isSuspicious = false;
        SecurityParams storage params = $.securityParams;
        $.vault.handleReport(
            asset, report_.priceD18, timestamp - params.depositInterval, timestamp - params.redeemInterval
        );
        emit ReportAccepted(asset, report_.priceD18, timestamp);
    }

    /// @inheritdoc IOracle
    function setSecurityParams(SecurityParams calldata securityParams_) external onlyRole(SET_SECURITY_PARAMS_ROLE) {
        _setSecurityParams(securityParams_);
    }

    /// @inheritdoc IOracle
    function addSupportedAssets(address[] calldata assets) external onlyRole(ADD_SUPPORTED_ASSETS_ROLE) {
        _addSupportedAssets(assets);
    }

    /// @inheritdoc IOracle
    function removeSupportedAssets(address[] calldata assets) external onlyRole(REMOVE_SUPPORTED_ASSETS_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        EnumerableSet.AddressSet storage asset_ = $.supportedAssets;
        mapping(address => DetailedReport) storage reports_ = $.reports;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!asset_.remove(assets[i])) {
                revert UnsupportedAsset(assets[i]);
            }
            delete reports_[assets[i]];
        }
        emit SupportedAssetsRemoved(assets);
    }

    // Internal functions

    function __Oracle_init(bytes calldata initParams) internal onlyInitializing {
        __ReentrancyGuard_init();
        (SecurityParams memory securityParams_, address[] memory assets_) =
            abi.decode(initParams, (SecurityParams, address[]));
        _setSecurityParams(securityParams_);
        _addSupportedAssets(assets_);
    }

    function _handleReport(SecurityParams memory params, uint224 priceD18, DetailedReport storage report)
        internal
        returns (bool)
    {
        if (report.timestamp != 0 && params.timeout + report.timestamp > block.timestamp && !report.isSuspicious) {
            revert TooEarly(block.timestamp, params.timeout + report.timestamp);
        }
        (bool isValid, bool isSuspicious) = _validatePrice(priceD18, report, params);
        if (!isValid) {
            revert InvalidPrice(priceD18);
        }
        report.priceD18 = priceD18;
        report.timestamp = uint32(block.timestamp);
        report.isSuspicious = isSuspicious;
        return !isSuspicious;
    }

    function _validatePrice(uint256 priceD18, DetailedReport storage report, SecurityParams memory params)
        private
        view
        returns (bool isValid, bool isSuspicious)
    {
        uint256 prevPriceD18 = report.priceD18;
        if (prevPriceD18 == 0) {
            return (true, true);
        }
        uint256 absoluteDeviation = priceD18 > prevPriceD18 ? priceD18 - prevPriceD18 : prevPriceD18 - priceD18;
        uint256 relativeDeviationD18 = Math.mulDiv(absoluteDeviation, 1 ether, prevPriceD18);
        if (absoluteDeviation > params.maxAbsoluteDeviation || relativeDeviationD18 > params.maxRelativeDeviationD18) {
            return (false, false);
        }
        if (report.isSuspicious) {
            return (true, true);
        }
        if (
            absoluteDeviation > params.suspiciousAbsoluteDeviation
                || relativeDeviationD18 > params.suspiciousRelativeDeviationD18
        ) {
            return (true, true);
        }
        return (true, false);
    }

    function _setSecurityParams(SecurityParams memory params) private {
        OracleStorage storage $ = _oracleStorage();
        if (
            params.maxAbsoluteDeviation == 0 || params.suspiciousAbsoluteDeviation == 0
                || params.maxRelativeDeviationD18 == 0 || params.suspiciousRelativeDeviationD18 == 0 || params.timeout == 0
                || params.depositInterval == 0 || params.redeemInterval == 0
        ) {
            revert ZeroValue();
        }
        $.securityParams = params;
        emit SecurityParamsSet(params);
    }

    function _addSupportedAssets(address[] memory assets) private {
        EnumerableSet.AddressSet storage asset_ = _oracleStorage().supportedAssets;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!asset_.add(assets[i])) {
                revert AlreadySupportedAsset(assets[i]);
            }
        }
        emit SupportedAssetsAdded(assets);
    }

    function _oracleStorage() internal view returns (OracleStorage storage $) {
        bytes32 slot = _oracleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
