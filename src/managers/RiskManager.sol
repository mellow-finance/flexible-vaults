// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IRiskManager.sol";

import "../libraries/SlotLibrary.sol";

contract RiskManager is IRiskManager, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SET_VAULT_LIMIT_ROLE = keccak256("managers.RiskManager.SET_VAULT_LIMIT_ROLE");
    bytes32 public constant SET_SUBVAULT_LIMIT_ROLE = keccak256("managers.RiskManager.SET_SUBVAULT_LIMIT_ROLE");
    bytes32 public constant ALLOW_SUBVAULT_ASSETS_ROLE = keccak256("managers.RiskManager.ALLOW_SUBVAULT_ASSETS_ROLE");
    bytes32 public constant DISALLOW_SUBVAULT_ASSETS_ROLE =
        keccak256("managers.RiskManager.DISALLOW_SUBVAULT_ASSETS_ROLE");
    bytes32 public constant MODIFY_PENDING_ASSETS_ROLE = keccak256("managers.RiskManager.MODIFY_PENDING_ASSETS_ROLE");
    bytes32 public constant MODIFY_VAULT_BALANCE_ROLE = keccak256("managers.RiskManager.MODIFY_VAULT_BALANCE_ROLE");
    bytes32 public constant MODIFY_SUBVAULT_BALANCE_ROLE =
        keccak256("managers.RiskManager.MODIFY_SUBVAULT_BALANCE_ROLE");

    bytes32 private immutable _riskManagerStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _riskManagerStorageSlot = SlotLibrary.getSlot("RiskManager", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        if (!IACLModule(vault()).hasRole(role, _msgSender())) {
            revert Forbidden();
        }
        _;
    }

    modifier onlyVaultOrRole(bytes32 role) {
        address caller = _msgSender();
        address vault_ = vault();
        if (caller != vault_ && !IACLModule(vault_).hasRole(role, caller)) {
            revert Forbidden();
        }
        _;
    }

    modifier onlyQueueOrRole(bytes32 role) {
        address caller = _msgSender();
        address vault_ = vault();
        if (!IShareModule(vault_).hasQueue(caller) && !IACLModule(vault_).hasRole(role, caller)) {
            revert Forbidden();
        }
        _;
    }

    /// @inheritdoc IRiskManager
    function requireValidSubvault(address vault_, address subvault) public view {
        if (!IVaultModule(vault_).hasSubvault(subvault)) {
            revert NotSubvault(subvault);
        }
    }

    /// @inheritdoc IRiskManager
    function vault() public view returns (address) {
        return _riskManagerStorage().vault;
    }

    /// @inheritdoc IRiskManager
    function vaultState() public view returns (State memory) {
        return _riskManagerStorage().vaultState;
    }

    /// @inheritdoc IRiskManager
    function pendingBalance() public view returns (int256) {
        return _riskManagerStorage().pendingBalance;
    }

    /// @inheritdoc IRiskManager
    function pendingAssets(address asset) public view returns (int256) {
        return _riskManagerStorage().pendingAssets[asset];
    }

    /// @inheritdoc IRiskManager
    function pendingShares(address asset) public view returns (int256) {
        return _riskManagerStorage().pendingShares[asset];
    }

    /// @inheritdoc IRiskManager
    function subvaultState(address subvault) public view returns (State memory) {
        return _riskManagerStorage().subvaultStates[subvault];
    }

    /// @inheritdoc IRiskManager
    function allowedAssets(address subvault) public view returns (uint256) {
        return _riskManagerStorage().allowedAssets[subvault].length();
    }

    /// @inheritdoc IRiskManager
    function allowedAssetAt(address subvault, uint256 index) public view returns (address) {
        return _riskManagerStorage().allowedAssets[subvault].at(index);
    }

    /// @inheritdoc IRiskManager
    function isAllowedAsset(address subvault, address asset) public view returns (bool) {
        return _riskManagerStorage().allowedAssets[subvault].contains(asset);
    }

    /// @inheritdoc IRiskManager
    function convertToShares(address asset, int256 value) public view returns (int256 shares) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        IOracle.DetailedReport memory report = IShareModule($.vault).oracle().getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            revert InvalidReport();
        }
        if (value < 0) {
            return -int256(Math.mulDiv(uint256(-value), report.priceD18, 1 ether));
        } else {
            return int256(Math.mulDiv(uint256(value), report.priceD18, 1 ether));
        }
    }

    /// @inheritdoc IRiskManager
    function maxDeposit(address subvault, address asset) public view returns (uint256 limit) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        if (!$.allowedAssets[subvault].contains(asset)) {
            return 0;
        }
        State storage state = $.subvaultStates[subvault];
        int256 shares = state.limit - state.balance;
        if (shares <= 0) {
            return 0;
        }
        IOracle.DetailedReport memory report = IShareModule($.vault).oracle().getReport(asset);
        if (report.isSuspicious || report.priceD18 == 0) {
            return 0;
        }
        return Math.mulDiv(uint256(shares), 1 ether, report.priceD18);
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        _riskManagerStorage().vaultState.limit = abi.decode(data, (int256));
        emit Initialized(data);
    }

    function setVault(address vault_) external {
        if (vault_ == address(0)) {
            revert ZeroValue();
        }
        RiskManagerStorage storage $ = _riskManagerStorage();
        if ($.vault != address(0)) {
            revert InvalidInitialization();
        }
        $.vault = vault_;
        emit SetVault(vault_);
    }

    /// @inheritdoc IRiskManager
    function setSubvaultLimit(address subvault, int256 limit) external onlyRole(SET_SUBVAULT_LIMIT_ROLE) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        $.subvaultStates[subvault].limit = limit;
        emit SetSubvaultLimit(subvault, limit);
    }

    /// @inheritdoc IRiskManager
    function allowSubvaultAssets(address subvault, address[] calldata assets)
        external
        onlyRole(ALLOW_SUBVAULT_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        EnumerableSet.AddressSet storage assets_ = $.allowedAssets[subvault];
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assets_.add(assets[i])) {
                revert AlreadyAllowedAsset(assets[i]);
            }
        }
        emit AllowSubvaultAssets(subvault, assets);
    }

    /// @inheritdoc IRiskManager
    function disallowSubvaultAssets(address subvault, address[] calldata assets)
        external
        onlyRole(DISALLOW_SUBVAULT_ASSETS_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        EnumerableSet.AddressSet storage assets_ = $.allowedAssets[subvault];
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assets_.remove(assets[i])) {
                revert NotAllowedAsset(assets[i]);
            }
        }
        emit DisallowSubvaultAssets(subvault, assets);
    }

    /// @inheritdoc IRiskManager
    function setVaultLimit(int256 limit) external onlyRole(SET_VAULT_LIMIT_ROLE) {
        _riskManagerStorage().vaultState.limit = limit;
        emit SetVaultLimit(limit);
    }

    /// @inheritdoc IRiskManager
    function modifyPendingAssets(address asset, int256 change) external onlyQueueOrRole(MODIFY_PENDING_ASSETS_ROLE) {
        RiskManagerStorage storage $ = _riskManagerStorage();
        int256 pendingAssetsBefore = $.pendingAssets[asset];
        int256 pendingSharesBefore = $.pendingShares[asset];
        int256 pendingAssetsAfter = pendingAssetsBefore + change;
        int256 pendingSharesAfter = convertToShares(asset, pendingAssetsAfter);
        int256 shares = pendingSharesAfter - pendingSharesBefore;
        int256 newPendingBalance = $.pendingBalance + shares;
        if (shares > 0 && $.vaultState.balance + newPendingBalance > $.vaultState.limit) {
            revert LimitExceeded($.vaultState.balance + newPendingBalance, $.vaultState.limit);
        }
        $.pendingAssets[asset] = pendingAssetsAfter;
        $.pendingShares[asset] = pendingSharesAfter;
        $.pendingBalance = newPendingBalance;
        emit ModifyPendingAssets(asset, change, pendingAssetsAfter, pendingSharesAfter);
    }

    /// @inheritdoc IRiskManager
    function modifyVaultBalance(address asset, int256 change) external onlyQueueOrRole(MODIFY_VAULT_BALANCE_ROLE) {
        int256 shares = convertToShares(asset, change);
        RiskManagerStorage storage $ = _riskManagerStorage();
        int256 newBalance = $.vaultState.balance + shares;
        if (shares > 0 && newBalance + $.pendingBalance > $.vaultState.limit) {
            revert LimitExceeded(newBalance + $.pendingBalance, $.vaultState.limit);
        }
        $.vaultState.balance = newBalance;
        emit ModifyVaultBalance(asset, shares, newBalance);
    }

    /// @inheritdoc IRiskManager
    function modifySubvaultBalance(address subvault, address asset, int256 change)
        external
        onlyVaultOrRole(MODIFY_SUBVAULT_BALANCE_ROLE)
    {
        RiskManagerStorage storage $ = _riskManagerStorage();
        requireValidSubvault($.vault, subvault);
        if (!$.allowedAssets[subvault].contains(asset)) {
            revert NotAllowedAsset(asset);
        }
        State storage state = $.subvaultStates[subvault];
        int256 shares = convertToShares(asset, change);
        int256 newBalance = state.balance + shares;
        if (shares > 0 && newBalance > state.limit) {
            revert LimitExceeded(newBalance, state.limit);
        }
        state.balance = newBalance;
        emit ModifySubvaultBalance(subvault, asset, change, newBalance);
    }

    // Internal functions

    function _riskManagerStorage() internal view returns (RiskManagerStorage storage $) {
        bytes32 slot = _riskManagerStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
