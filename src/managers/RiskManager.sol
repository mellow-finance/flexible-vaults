// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IRiskManager.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";

contract RiskManager is IRiskManager, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _riskManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _riskManagerStorageSlot = SlotLibrary.getSlot("RiskManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(IACLModule(vault()).hasRole(role, _msgSender()), "RiskManager: caller does not have the required role");
        _;
    }

    function requireValidSubvault(address vault_, address subvault) public view {
        if (!IVaultModule(vault_).hasSubvault(subvault)) {
            revert("RiskManager: not a valid subvault");
        }
    }

    function vault() public view returns (address) {
        return _riskManagerStorage().vault;
    }

    function convertToShares(address asset, int256 value) public view returns (int256 shares) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        IOracle.DetailedReport memory report = IShareModule($.vault).oracle().getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            revert("RiskManager: report is suspicious or has zero price");
        }
        shares = int256(Math.mulDiv(uint256(value < 0 ? -value : value), report.priceD18, 1 ether));
        if (value < 0) {
            shares = -shares;
        }
    }

    function maxDeposit(address subvault, address asset) public view returns (uint256 limit) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        State storage state = $.subvaultStates[subvault];
        if (!$.allowedAssets[subvault].contains(asset)) {
            return 0;
        }
        int256 shares = state.limit - state.balance;
        if (shares <= 0) {
            return 0;
        }
        IOracle.DetailedReport memory report = IShareModule($.vault).oracle().getReport(asset);
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
        requireValidSubvault($.vault, subvault);
        $.subvaultStates[subvault].limit = limit;
    }

    function addSubvaultAllowedAssets(address subvault, address[] calldata assets)
        external
        onlyRole(PermissionsLibrary.ADD_SUBVAULT_ALLOWED_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        EnumerableSet.AddressSet storage assets_ = $.allowedAssets[subvault];
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assets_.add(assets[i])) {
                revert("RiskManager: asset already allowed in subvault");
            }
        }
    }

    function removeSubvaultAllowedAssets(address subvault, address[] calldata assets)
        external
        onlyRole(PermissionsLibrary.REMOVE_SUBVAULT_ALLOWED_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        EnumerableSet.AddressSet storage assets_ = $.allowedAssets[subvault];
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assets_.remove(assets[i])) {
                revert("RiskManager: asset not allowed in subvault");
            }
        }
    }

    function setVaultLimit(int256 limit) external onlyRole(PermissionsLibrary.SET_VAULT_LIMIT_ROLE) {
        _riskManagerStorage().vaultState.limit = limit;
    }

    function modifyPendingAssets(address asset, int256 change)
        external
        onlyRole(PermissionsLibrary.MODIFY_PENDING_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        uint256 pendingAssetsBefore = $.pendingAssets[asset];
        uint256 pendingAssetsAfter = uint256(int256(pendingAssetsBefore) + change);
        uint256 pendingSharesBefore = $.pendingShares[asset];
        uint256 pendingSharesAfter = uint256(convertToShares(asset, int256(pendingAssetsAfter)));
        $.pendingAssets[asset] = pendingAssetsAfter;
        $.pendingShares[asset] = pendingSharesAfter;
        int256 sharesChange = int256(pendingSharesAfter) - int256(pendingSharesBefore);
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
        requireValidSubvault($.vault, subvault);
        if (!$.allowedAssets[subvault].contains(asset)) {
            revert("RiskManager: asset not allowed in subvault");
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
