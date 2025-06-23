// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "../factories/IFactoryEntity.sol";

import "../modules/IACLModule.sol";
import "../modules/IShareModule.sol";
import "../modules/IVaultModule.sol";
import "../oracles/IOracle.sol";

interface IRiskManager is IFactoryEntity {
    struct State {
        int256 balance;
        int256 limit;
    }

    struct RiskManagerStorage {
        address vault;
        State vaultState;
        int256 pendingBalance;
        mapping(address asset => int256) pendingAssets;
        mapping(address asset => int256) pendingShares;
        mapping(address subvault => State) subvaultStates;
    }

    function modifyVaultBalance(address asset, int256 delta) external;

    function modifySubvaultBalance(address subvault, address asset, int256 delta) external;

    function setVaultLimit(int256 limit) external;

    function setSubvaultLimit(address subvault, int256 limit) external;

    function modifyPendingAssets(address asset, int256 change) external;

    function convertToShares(address asset, int256 assets) external view returns (int256 shares);

    function maxDeposit(address asset) external view returns (uint256 limit);

    function maxDeposit(address subvault, address asset) external view returns (uint256 limit);
}
