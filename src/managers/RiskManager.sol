// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IRiskManager.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";

contract RiskManager is IRiskManager, ContextUpgradeable {
    modifier onlyRole(bytes32 role) {
        require(IACLModule(vault()).hasRole(role, _msgSender()), "RiskManager: caller does not have the required role");
        _;
    }

    bytes32 private immutable _riskManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _riskManagerStorageSlot = SlotLibrary.getSlot("RiskManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    function vault() public view returns (address) {
        return _riskManagerStorage().vault;
    }

    function convertToShares(address asset, int256 value) public view returns (int256 shares) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        IOracle oracle = IShareModule($.vault).depositOracle();
        IOracle.DetailedReport memory report = oracle.getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            revert("RiskManager: report is suspicious or has zero price");
        }
        shares = int256(Math.mulDiv(uint256(value < 0 ? -value : value), report.priceD18, 1 ether));
        if (value < 0) {
            shares = -shares;
        }
    }

    function maxDeposit(address asset) public view returns (uint256 limit) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        State storage state = $.vaultState;
        int256 shares = state.limit - state.balance - $.pendingBalance;
        if (shares <= 0) {
            return 0;
        }
        IOracle oracle = IShareModule($.vault).depositOracle();
        IOracle.DetailedReport memory report = oracle.getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            return 0;
        }
        uint256 priceD18 = report.priceD18;
        return Math.mulDiv(uint256(shares), 1 ether, priceD18);
    }

    function maxDeposit(address subvault, address asset) public view returns (uint256 limit) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        State storage state = $.subvaultStates[subvault];
        int256 shares = state.limit - state.balance;
        if (shares <= 0) {
            return 0;
        }
        IOracle oracle = IShareModule($.vault).depositOracle();
        IOracle.DetailedReport memory report = oracle.getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            return 0;
        }
        uint256 priceD18 = report.priceD18;
        return Math.mulDiv(uint256(shares), 1 ether, priceD18);
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (address vault_, int256 vaultLimit_) = abi.decode(data, (address, int256));
        RiskManagerStorage storage $ = _riskManagerStorage();
        $.vault = vault_;
        $.vaultState.limit = vaultLimit_;
    }

    function setSubvaultLimit(address subvault, int256 limit)
        external
        onlyRole(PermissionsLibrary.SET_SUBVAULT_LIMIT_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        if (!IVaultModule($.vault).hasSubvault(subvault)) {
            revert("RiskManager: not a valid subvault");
        }
        $.subvaultStates[subvault].limit = limit;
    }

    function setVaultLimit(int256 limit) external onlyRole(PermissionsLibrary.SET_VAULT_LIMIT_ROLE) {
        _riskManagerStorage().vaultState.limit = limit;
    }

    function modifyPendingAssets(address asset, int256 change)
        external
        onlyRole(PermissionsLibrary.MODIFY_PENDING_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        int256 sharesChange = convertToShares(asset, change);
        $.pendingAssets[asset] += change;
        $.pendingShares[asset] += sharesChange;
        $.pendingBalance += sharesChange;
        if (sharesChange > 0 && $.vaultState.balance + $.pendingBalance > $.vaultState.limit) {
            revert("RiskManager: root vault limit exceeded");
        }
    }

    function modifyVaultBalance(address asset, int256 change)
        external
        onlyRole(PermissionsLibrary.MODIFY_VAULT_BALANCE_ROLE)
    {
        int256 shares = convertToShares(asset, change);
        RiskManagerStorage storage $ = _riskManagerStorage();
        if (shares > 0 && $.vaultState.balance + $.pendingBalance + shares > $.vaultState.limit) {
            revert("RiskManager: root vault limit exceeded");
        }
        $.vaultState.balance += change;
    }

    function modifySubvaultBalance(address subvault, address asset, int256 change)
        external
        onlyRole(PermissionsLibrary.MODIFY_SUBVAULT_BALANCE_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        if (!IVaultModule($.vault).hasSubvault(subvault)) {
            revert("RiskManager: not a valid subvault");
        }
        State storage state = $.subvaultStates[subvault];
        int256 shares = convertToShares(asset, change);
        if (shares > 0 && state.balance + shares > state.limit) {
            revert("RiskManager: subvault limit exceeded");
        }
        state.balance += change;
    }

    // Internal functions

    function _riskManagerStorage() internal view returns (RiskManagerStorage storage $) {
        bytes32 slot = _riskManagerStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
