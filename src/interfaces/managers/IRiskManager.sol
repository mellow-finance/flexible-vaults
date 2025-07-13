// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

import "../modules/IACLModule.sol";
import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "../oracles/IOracle.sol";

/// @notice Interface for the RiskManager contract
/// @dev Handles vault and subvault balance limits, pending asset tracking, and asset permissioning
interface IRiskManager is IFactoryEntity {
    /// @notice Thrown when the caller lacks appropriate permission
    error Forbidden();

    /// @notice Thrown when a price report is flagged as suspicious, or has not been set yet.
    error InvalidReport();

    /// @notice Thrown when attempting to allow an already allowed asset
    error AlreadyAllowedAsset(address asset);

    /// @notice Thrown when attempting to disallow or use a non-allowed asset
    error NotAllowedAsset(address asset);

    /// @notice Thrown when a vault or subvault exceeds its configured limit
    error LimitExceeded(int256 newValue, int256 maxValue);

    /// @notice Thrown when a given address is not recognized as a valid subvault
    error NotSubvault(address subvault);

    /// @notice Thrown when a zero address is passed as a parameter
    error ZeroValue();

    /// @notice Tracks current and maximum balance for a vault or subvault
    struct State {
        int256 balance; // Current approximate shares held
        int256 limit; // Maximum allowable approximate shares
    }

    /// @notice Storage layout for RiskManager.
    struct RiskManagerStorage {
        address vault; // Address of the Vault associated with this risk manager.
        State vaultState; // Tracks the share balance and limit for the Vault.
        int256 pendingBalance;
        /// Cumulative approximate share balance from all pending requests in all deposit queues. Used to track unprocessed inflows.
        mapping(address asset => int256) pendingAssets; // Pending inflow amount per asset.
        mapping(address asset => int256) pendingShares; // Pending inflow amount in shares per asset converted by the last oracle report.
        mapping(address subvault => State) subvaultStates; // Share state tracking for each connected subvault.
        mapping(address subvault => EnumerableSet.AddressSet) allowedAssets; // List of assets that each subvault is allowed to interact with.
    }

    /// @notice Reverts if the given subvault is not valid for the vault
    function requireValidSubvault(address vault_, address subvault) external view;

    /// @notice Returns the address of the Vault
    function vault() external view returns (address);

    /// @notice Returns the approximate share balance and the share limit limit of the vault.
    function vaultState() external view returns (State memory);

    /// @notice Returns the pending share balance across all assets and deposit queues.
    function pendingBalance() external view returns (int256);

    /// @notice Returns the pending asset value for a specific asset
    function pendingAssets(address asset) external view returns (int256);

    /// @notice Returns the pending shares equivalent of a specific asset converted by the last oracle report for the given asset.
    function pendingShares(address asset) external view returns (int256);

    /// @notice Returns the approximate balance and the limit of a specific subvault
    function subvaultState(address subvault) external view returns (State memory);

    /// @notice Returns number of assets allowed for a given subvault
    function allowedAssets(address subvault) external view returns (uint256);

    /// @notice Returns the allowed asset at a given index for a subvault
    function allowedAssetAt(address subvault, uint256 index) external view returns (address);

    /// @notice Checks if an asset is allowed for the specified subvault
    function isAllowedAsset(address subvault, address asset) external view returns (bool);

    /// @notice Converts an asset amount into its equivalent share representation by the last oracle report
    /// @param asset Asset being valued
    /// @param value Amount in asset units (can be positive or negative)
    /// @return shares Share amount
    function convertToShares(address asset, int256 value) external view returns (int256 shares);

    /// @notice Returns the maximum amount that can be deposited into a subvault for a specific asset
    function maxDeposit(address subvault, address asset) external view returns (uint256 limit);

    /// @notice Modifies the vault's internal balance by a signed delta (in asset terms)
    function modifyVaultBalance(address asset, int256 delta) external;

    /// @notice Modifies a subvault's internal balance by a signed delta (in asset terms)
    function modifySubvaultBalance(address subvault, address asset, int256 delta) external;

    /// @notice Sets the maximum allowable approximate (soft) balance for the entire vault in shares
    function setVaultLimit(int256 limit) external;

    /// @notice Sets the maximum allowable approximate (soft) balance for a specific subvault
    function setSubvaultLimit(address subvault, int256 limit) external;

    /// @notice Allows specific assets to be used in a subvault
    function allowSubvaultAssets(address subvault, address[] calldata assets) external;

    /// @notice Disallows specific assets from being used in a subvault
    function disallowSubvaultAssets(address subvault, address[] calldata assets) external;

    /// @notice Modifies the vault's pending balances by a signed delta (in asset terms)
    function modifyPendingAssets(address asset, int256 change) external;

    /// @notice Sets the vault address this RiskManager is associated with
    function setVault(address vault_) external;

    /// @notice Emitted when a limit is set for a specific subvault
    event SetSubvaultLimit(address indexed subvault, int256 limit);

    /// @notice Emitted when the vault limit is updated
    event SetVaultLimit(int256 limit);

    /// @notice Emitted when assets are newly allowed for a subvault
    event AllowSubvaultAssets(address indexed subvault, address[] assets);

    /// @notice Emitted when assets are disallowed from a subvault
    event DisallowSubvaultAssets(address indexed subvault, address[] assets);

    /// @notice Emitted when pending asset balances are updated
    event ModifyPendingAssets(
        address indexed asset, int256 change, int256 pendingAssetsAfter, int256 pendingSharesAfter
    );

    /// @notice Emitted when the vault balance is changed
    event ModifyVaultBalance(address indexed asset, int256 shares, int256 newBalance);

    /// @notice Emitted when a subvault's balance is changed
    event ModifySubvaultBalance(address indexed subvault, address indexed asset, int256 change, int256 newBalance);

    /// @notice Emitted when the associated vault address is set
    event SetVault(address indexed vault);
}
