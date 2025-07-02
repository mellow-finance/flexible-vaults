// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IFeeManager is IFactoryEntity {
    error ZeroAddress();
    error InvalidDepositFee(uint256 fee);
    error InvalidRedeemFee(uint256 fee);
    error InvalidPerformanceFee(uint256 fee);
    error InvalidProtocolFee(uint256 fee);
    error BaseAssetAlreadSet(address vault, address baseAsset);

    struct FeeManagerStorage {
        address feeRecipient;
        uint24 depositFeeD6;
        uint24 redeemFeeD6;
        uint24 performanceFeeD6;
        uint24 protocolFeeD6;
        mapping(address vault => uint256) timestamps;
        mapping(address vault => uint256) maxPriceD18;
        mapping(address vault => address) baseAsset;
    }

    function feeRecipient() external view returns (address);
    function depositFeeD6() external view returns (uint24);
    function redeemFeeD6() external view returns (uint24);
    function performanceFeeD6() external view returns (uint24);
    function protocolFeeD6() external view returns (uint24);
    function timestamps(address vault) external view returns (uint256);
    function maxPriceD18(address vault) external view returns (uint256);
    function baseAsset(address vault) external view returns (address);

    function calculateDepositFee(uint256 amount) external view returns (uint256);
    function calculateRedeemFee(uint256 amount) external view returns (uint256);
    function calculatePerformanceFee(address vault, address asset, uint256 priceD18) external view returns (uint256);
    function calculateProtocolFee(address vault, uint256 totalShares) external view returns (uint256 shares);

    // Mutable functions
    function setFeeRecipient(address feeRecipient_) external;
    function setFees(uint24 depositFeeD6_, uint24 redeemFeeD6_, uint24 performanceFeeD6_, uint24 protocolFeeD6_)
        external;
    function setBaseAsset(address vault, address baseAsset_) external;
    function updateState(address asset, uint256 priceD18) external;

    event SetFeeRecipient(address feeRecipient);
    event SetFees(uint24 depositFeeD6, uint24 redeemFeeD6, uint24 performanceFeeD6, uint24 protocolFeeD6);
    event SetBaseAsset(address vault, address baseAsset);
    event UpdateState(address vault, address asset, uint256 priceD18);
}
