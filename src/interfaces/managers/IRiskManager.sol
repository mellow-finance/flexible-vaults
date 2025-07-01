// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../factories/IFactoryEntity.sol";

import "../modules/IACLModule.sol";
import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "../oracles/IOracle.sol";

interface IRiskManager is IFactoryEntity {
    error Forbidden();
    error InvalidReport();
    error AlreadyAllowedAsset(address asset);
    error NotAllowedAsset(address asset);
    error LimitExceeded(int256 newValue, int256 maxValue);
    error NotSubvault(address subvault);

    struct State {
        int256 balance;
        int256 limit;
    }

    struct RiskManagerStorage {
        address vault;
        State vaultState;
        int256 pendingBalance;
        mapping(address asset => uint256) pendingAssets;
        mapping(address asset => uint256) pendingShares;
        mapping(address subvault => State) subvaultStates;
        mapping(address subvault => EnumerableSet.AddressSet) allowedAssets;
    }

    // View functions

    function requireValidSubvault(address vault_, address subvault) external view;
    function vault() external view returns (address);
    function vaultState() external view returns (State memory);
    function pendingBalance() external view returns (int256);
    function pendingAssets(address asset) external view returns (uint256);
    function pendingShares(address asset) external view returns (uint256);
    function subvaultState(address subvault) external view returns (State memory);
    function allowedAssets(address subvault) external view returns (uint256);
    function allowedAssetAt(address subvault, uint256 index) external view returns (address);
    function isAllowedAsset(address subvault, address asset) external view returns (bool);
    function convertToShares(address asset, int256 value) external view returns (int256 shares);
    function maxDeposit(address subvault, address asset) external view returns (uint256 limit);

    // Mutable functions

    function modifyVaultBalance(address asset, int256 delta) external;

    function modifySubvaultBalance(address subvault, address asset, int256 delta) external;

    function setVaultLimit(int256 limit) external;

    function setSubvaultLimit(address subvault, int256 limit) external;

    function allowSubvaultAssets(address subvault, address[] calldata assets) external;

    function disallowSubvaultAssets(address subvault, address[] calldata assets) external;

    function modifyPendingAssets(address asset, int256 change) external;

    // Events

    event SetSubvaultLimit(address indexed subvault, int256 limit);
    event SetVaultLimit(int256 limit);
    event AllowSubvaultAssets(address indexed subvault, address[] assets);
    event DisallowSubvaultAssets(address indexed subvault, address[] assets);
    event ModifyPendingAssets(
        address indexed asset, int256 change, uint256 pendingAssetsAfter, uint256 pendingSharesAfter
    );
    event ModifyVaultBalance(address indexed asset, int256 change, int256 newBalance);
    event ModifySubvaultBalance(address indexed subvault, address indexed asset, int256 change, int256 newBalance);
    event ModifySubvaultAssets(
        address indexed subvault,
        address indexed asset,
        int256 change,
        uint256 pendingAssetsAfter,
        uint256 pendingSharesAfter
    );
}
