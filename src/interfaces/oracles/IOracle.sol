// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";
import "../modules/ISharesModule.sol";

interface IOracle is IFactoryEntity {
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
        ISharesModule vault;
        SecurityParams securityParams;
        EnumerableSet.AddressSet supportedAssets;
        mapping(address asset => DetailedReport) reports;
    }

    function vault() external view returns (ISharesModule);

    function securityParams() external view returns (SecurityParams memory);

    function supportedAssets() external view returns (address[] memory);

    function isSupportedAsset(address asset) external view returns (bool);

    function getReport(address asset) external view returns (DetailedReport memory);

    function validatePrice(uint256 priceD18, uint256 prevPriceD18)
        external
        view
        returns (bool isValid, bool isSuspicious);

    function sendReport(Report[] calldata reports) external;

    function acceptReport(address asset, uint32 timestamp) external;

    function setSecurityParams(SecurityParams calldata securityParams_) external;

    function addSupportedAssets(address[] calldata assets) external;

    function removeSupportedAssets(address[] calldata assets) external;
}
