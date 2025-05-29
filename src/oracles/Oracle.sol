// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/SlotLibrary.sol";
import "../modules/SharesModule.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

contract Oracle is ContextUpgradeable {
    using Checkpoints for Checkpoints.Trace224;

    struct OracleStorage {
        SharesModule vault;
        uint224 maxAbsoluteDeviation;
        uint64 maxRelativeDeviationD18;
        uint224 suspiciousAbsoluteDeviation;
        uint64 suspiciousRelativeDeviationD18;
        uint32 timeout;
        uint32 depositSecureT;
        uint32 redeemSecureT;
        bool isLocked;
        mapping(address asset => Checkpoints.Trace224) depositPriceReports;
        mapping(address asset => Checkpoints.Trace224) redeemPriceReports;
    }

    struct Report {
        address asset;
        uint224 depositPriceD18; // assets * price = shares
        uint224 redeemPriceD18; // shares * price = assets
    }

    struct Stack {
        SharesModule vault;
        uint224 maxAbsoluteDeviation;
        uint64 maxRelativeDeviationD18;
        uint224 suspiciousAbsoluteDeviation;
        uint64 suspiciousRelativeDeviationD18;
        uint32 timestamp;
        uint32 timeout;
        uint32 depositSecureT;
        uint32 redeemSecureT;
        bool isLocked;
        uint224 price;
    }

    bytes32 public constant REPORT_PRICES_ROLE = keccak256("ORACLE:REPORT_PRICES_ROLE");
    bytes32 public constant SET_MAX_ABSOLUTE_DEVIATION_ROLE =
        keccak256("ORACLE:SET_MAX_ABSOLUTE_DEVIATION_ROLE");
    bytes32 public constant SET_MAX_RELATIVE_DEVIATION_ROLE =
        keccak256("ORACLE:SET_MAX_RELATIVE_DEVIATION_ROLE");
    bytes32 public constant SET_TIMEOUT_ROLE = keccak256("ORACLE:SET_TIMEOUT_ROLE");
    bytes32 public constant SET_DEPOSIT_SECURE_T_ROLE =
        keccak256("ORACLE:SET_DEPOSIT_SECURE_T_ROLE");
    bytes32 public constant SET_REDEEM_SECURE_T_ROLE = keccak256("ORACLE:SET_REDEEM_SECURE_T_ROLE");
    bytes32 public constant UNLOCK_ROLE = keccak256("ORACLE:UNLOCK_ROLE");
    bytes32 private immutable _oracleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _oracleStorageSlot = SlotLibrary.getSlot("Oracle", name_, version_);
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(
            IAccessControl(address(_oracleStorage().vault)).hasRole(role, _msgSender()),
            "Oracle: forbidden"
        );
        _;
    }

    function vault() public view returns (SharesModule) {
        return _oracleStorage().vault;
    }

    function timeout() public view returns (uint32) {
        return _oracleStorage().timeout;
    }

    function maxAbsoluteDeviation() public view returns (uint224) {
        return _oracleStorage().maxAbsoluteDeviation;
    }

    function maxRelativeDeviationD18() public view returns (uint256) {
        return _oracleStorage().maxRelativeDeviationD18;
    }

    function depositSecureT() public view returns (uint32) {
        return _oracleStorage().depositSecureT;
    }

    function redeemSecureT() public view returns (uint32) {
        return _oracleStorage().redeemSecureT;
    }

    function depositPriceReportAt(address asset, uint32 index)
        public
        view
        returns (Checkpoints.Checkpoint224 memory)
    {
        return _oracleStorage().depositPriceReports[asset].at(index);
    }

    function depositPriceReportsLength(address asset) public view returns (uint256) {
        return _oracleStorage().depositPriceReports[asset].length();
    }

    function redeemPriceReportAt(address asset, uint32 index)
        public
        view
        returns (Checkpoints.Checkpoint224 memory)
    {
        return _oracleStorage().redeemPriceReports[asset].at(index);
    }

    function redeemPriceReportsLength(address asset) public view returns (uint256) {
        return _oracleStorage().redeemPriceReports[asset].length();
    }

    function isLocked() public view returns (bool) {
        return _oracleStorage().isLocked;
    }

    function getDepositEpochPrice(address asset, uint256 epoch)
        public
        view
        returns (bool exists, uint224 priceD18)
    {
        OracleStorage storage $ = _oracleStorage();
        if ($.isLocked) {
            return (false, 0);
        }
        uint256 timestamp = SharesModule($.vault).endTimestampOf(epoch) + $.depositSecureT;
        if (timestamp > type(uint32).max) {
            return (false, 0);
        }
        priceD18 = $.depositPriceReports[asset].lowerLookup(uint32(timestamp));
        exists = priceD18 != 0;
    }

    function getRedeemEpochPrice(address asset, uint256 epoch)
        public
        view
        returns (bool exists, uint224 priceD18)
    {
        OracleStorage storage $ = _oracleStorage();
        if ($.isLocked) {
            return (false, 0);
        }
        uint256 timestamp = SharesModule($.vault).endTimestampOf(epoch) + $.redeemSecureT;
        if (timestamp > type(uint32).max) {
            return (false, 0);
        }
        priceD18 = $.redeemPriceReports[asset].lowerLookup(uint32(timestamp));
        exists = priceD18 != 0;
    }

    // Mutable functions

    function reportPrices(Report[] calldata reports) external onlyRole(REPORT_PRICES_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        // TODO: add sanity checks
        uint32 timestamp = uint32(block.timestamp);
        Stack memory stack = Stack({
            vault: $.vault,
            maxAbsoluteDeviation: $.maxAbsoluteDeviation,
            maxRelativeDeviationD18: $.maxRelativeDeviationD18,
            suspiciousAbsoluteDeviation: $.suspiciousAbsoluteDeviation,
            suspiciousRelativeDeviationD18: $.suspiciousRelativeDeviationD18,
            timestamp: timestamp,
            timeout: $.timeout,
            depositSecureT: $.depositSecureT,
            redeemSecureT: $.redeemSecureT,
            isLocked: $.isLocked,
            price: 0
        });
        for (uint256 i = 0; i < reports.length; i++) {
            Report calldata report = reports[i];
            stack.price = report.depositPriceD18;
            _handleReport($.depositPriceReports[report.asset], stack);
            stack.price = report.redeemPriceD18;
            _handleReport($.redeemPriceReports[report.asset], stack);
        }
        if (stack.isLocked) {
            $.isLocked = true;
        }
    }

    function setDeviations(
        uint224 maxAbsoluteDeviation_,
        uint64 maxRelativeDeviationD18_,
        uint224 suspiciousAbsoluteDeviation_,
        uint64 suspiciousRelativeDeviationD18_
    ) external onlyRole(SET_MAX_ABSOLUTE_DEVIATION_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        if (
            maxAbsoluteDeviation_ == 0 || maxRelativeDeviationD18_ == 0
                || suspiciousAbsoluteDeviation_ == 0 || suspiciousRelativeDeviationD18_ == 0
        ) {
            revert("Oracle: deviations cannot be zero");
        }
        if (
            maxAbsoluteDeviation_ <= suspiciousAbsoluteDeviation_
                || maxRelativeDeviationD18_ <= suspiciousRelativeDeviationD18_
        ) {
            revert("Oracle: max deviation cannot be less than suspicious deviation");
        }
        $.maxAbsoluteDeviation = maxAbsoluteDeviation_;
        $.maxRelativeDeviationD18 = maxRelativeDeviationD18_;
        $.suspiciousAbsoluteDeviation = suspiciousAbsoluteDeviation_;
        $.suspiciousRelativeDeviationD18 = suspiciousRelativeDeviationD18_;
    }

    function setTimeout(uint32 timeout_) external onlyRole(SET_TIMEOUT_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        $.timeout = timeout_;
    }

    function setDepositSecureT(uint32 depositSecureT_)
        external
        onlyRole(SET_DEPOSIT_SECURE_T_ROLE)
    {
        OracleStorage storage $ = _oracleStorage();
        $.depositSecureT = depositSecureT_;
    }

    function setRedeemSecureT(uint32 redeemSecureT_) external onlyRole(SET_REDEEM_SECURE_T_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        $.redeemSecureT = redeemSecureT_;
    }

    function unlock() external onlyRole(UNLOCK_ROLE) {
        OracleStorage storage $ = _oracleStorage();
        $.isLocked = false;
    }

    // Internal functions

    function __Oracle_init(
        SharesModule vault_,
        uint224 maxAbsoluteDeviation_,
        uint64 maxRelativeDeviationD18_,
        uint224 suspiciousAbsoluteDeviation_,
        uint64 suspiciousRelativeDeviationD18_,
        uint32 timeout_,
        uint32 depositSecureT_,
        uint32 redeemSecureT_
    ) internal onlyInitializing {
        OracleStorage storage $ = _oracleStorage();
        $.vault = vault_;
        $.maxAbsoluteDeviation = maxAbsoluteDeviation_;
        $.maxRelativeDeviationD18 = maxRelativeDeviationD18_;
        $.suspiciousAbsoluteDeviation = suspiciousAbsoluteDeviation_;
        $.suspiciousRelativeDeviationD18 = suspiciousRelativeDeviationD18_;
        $.timeout = timeout_;
        $.depositSecureT = depositSecureT_;
        $.redeemSecureT = redeemSecureT_;
    }

    function _handleReport(Checkpoints.Trace224 storage reports, Stack memory $) internal {
        if ($.price == 0) {
            return;
        }
        (bool exists, uint32 prevTimestamp, uint224 prevPrice) = reports.latestCheckpoint();
        if (exists) {
            if (prevTimestamp + $.timeout >= $.timestamp) {
                revert("Oracle: too early to report");
            }
            uint224 absoluteDeviation =
                $.price > prevPrice ? $.price - prevPrice : prevPrice - $.price;
            if (absoluteDeviation > $.maxAbsoluteDeviation) {
                revert("Oracle: absolute deviation too high");
            }
            uint256 relativeDeviation = Math.mulDiv(absoluteDeviation, 1 ether, prevPrice);
            if (relativeDeviation > $.maxRelativeDeviationD18) {
                revert("Oracle: relative deviation too high");
            }
            if (
                absoluteDeviation > $.suspiciousAbsoluteDeviation
                    || relativeDeviation > $.suspiciousRelativeDeviationD18
            ) {
                $.isLocked = true;
            }
        }
        reports.push($.timestamp, $.price);
    }

    function _oracleStorage() internal view returns (OracleStorage storage $) {
        bytes32 slot = _oracleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
