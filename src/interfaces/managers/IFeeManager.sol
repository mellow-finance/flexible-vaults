// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Interface for the FeeManager contract
/// @dev Handles deposit, redeem, performance, and protocol fees for vaults, and tracks per-vault price/timestamp states
interface IFeeManager is IFactoryEntity {
    /// @notice Thrown when a required address is zero
    error ZeroAddress();

    /// @notice Thrown when the sum of all fees exceeds 100% (1e6 in D6 precision)
    error InvalidFees(uint24 depositFeeD6, uint24 redeemFeeD6, uint24 performanceFeeD6, uint24 protocolFeeD6);

    /// @notice Thrown when trying to overwrite a vault's base asset that was already set
    error BaseAssetAlreadySet(address vault, address baseAsset);

    /// @notice Storage layout used internally by FeeManager
    struct FeeManagerStorage {
        address feeRecipient; // Address that collects all fee shares
        uint24 depositFeeD6; // Deposit fee in 6 decimals (e.g. 10000 = 1%)
        uint24 redeemFeeD6; // Redeem fee in 6 decimals
        uint24 performanceFeeD6; // Performance fee applied on price increase (6 decimals)
        uint24 protocolFeeD6; // Protocol fee applied over time (6 decimals annualized)
        mapping(address vault => uint256) timestamps; // Last update timestamp for protocol fee accrual
        mapping(address vault => uint256) minPriceD18; // Lowests price seen for performance fee trigger (price * assets = shares)
        mapping(address vault => address) baseAsset; // Base asset used to evaluate price-based fees
    }

    /// @notice Returns the current fee recipient address
    function feeRecipient() external view returns (address);

    /// @notice Returns the configured deposit fee (in D6 precision)
    function depositFeeD6() external view returns (uint24);

    /// @notice Returns the configured redeem fee (in D6 precision)
    function redeemFeeD6() external view returns (uint24);

    /// @notice Returns the configured performance fee (in D6 precision)
    function performanceFeeD6() external view returns (uint24);

    /// @notice Returns the configured protocol fee (in D6 precision per year)
    function protocolFeeD6() external view returns (uint24);

    /// @notice Returns the last recorded timestamp for a given vault (used for protocol fee accrual)
    function timestamps(address vault) external view returns (uint256);

    /// @notice Returns the last recorded min price for a vault's base asset (used for performance fee)
    function minPriceD18(address vault) external view returns (uint256);

    /// @notice Returns the base asset configured for a vault
    function baseAsset(address vault) external view returns (address);

    /// @notice Calculates the deposit fee in shares based on the amount
    /// @param amount Number of shares being deposited
    /// @return Fee in shares to be deducted
    function calculateDepositFee(uint256 amount) external view returns (uint256);

    /// @notice Calculates the redeem fee in shares based on the amount
    /// @param amount Number of shares being redeemed
    /// @return Fee in shares to be deducted
    function calculateRedeemFee(uint256 amount) external view returns (uint256);

    /// @notice Calculates the combined performance and protocol fee in shares
    /// @param vault Address of the vault
    /// @param asset Asset used for pricing
    /// @param priceD18 Current vault share price for the specific `asset` (price = shares / assets)
    /// @param totalShares Total shares of the vault
    /// @return shares Fee to be added in shares
    function calculateFee(address vault, address asset, uint256 priceD18, uint256 totalShares)
        external
        view
        returns (uint256 shares);

    /// @notice Sets the recipient address for all collected fees
    /// @param feeRecipient_ Address to receive fees
    function setFeeRecipient(address feeRecipient_) external;

    /// @notice Sets the global fee configuration (deposit, redeem, performance, protocol)
    /// @dev Total of all fees must be <= 1e6 (i.e. 100%)
    function setFees(uint24 depositFeeD6_, uint24 redeemFeeD6_, uint24 performanceFeeD6_, uint24 protocolFeeD6_)
        external;

    /// @notice Sets the base asset for a vault, required for performance fee calculation
    /// @dev Can only be set once per vault
    function setBaseAsset(address vault, address baseAsset_) external;

    /// @notice Updates the vault's state (min price and timestamp) based on asset price only if `asset` == `baseAssets[vault]`
    /// @dev Used by the vault to notify FeeManager of new price highs or protocol fee accrual checkpoints
    function updateState(address asset, uint256 priceD18) external;

    /// @notice Emitted when the fee recipient is changed
    event SetFeeRecipient(address indexed feeRecipient);

    /// @notice Emitted when the fee configuration is updated
    event SetFees(uint24 depositFeeD6, uint24 redeemFeeD6, uint24 performanceFeeD6, uint24 protocolFeeD6);

    /// @notice Emitted when a vault's base asset is set
    event SetBaseAsset(address indexed vault, address indexed baseAsset);

    /// @notice Emitted when the vault's min price or timestamp is updated
    event UpdateState(address indexed vault, address indexed asset, uint256 priceD18);
}
