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

    function modifyVaultBalance(address asset, int256 delta) external;

    function modifySubvaultBalance(address subvault, address asset, int256 delta) external;

    function setVaultLimit(int256 limit) external;

    function setSubvaultLimit(address subvault, int256 limit) external;

    function allowSubvaultAssets(address subvault, address[] calldata assets) external;

    function disallowSubvaultAssets(address subvault, address[] calldata assets) external;

    function modifyPendingAssets(address asset, int256 change) external;

    function convertToShares(address asset, int256 assets) external view returns (int256 shares);

    function maxDeposit(address subvault, address asset) external view returns (uint256 limit);
}
