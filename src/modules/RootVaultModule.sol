// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IRootVaultModule.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

abstract contract RootVaultModule is IRootVaultModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _subvaultModuleStorageSlot;
    address public immutable subvaultFactory;

    constructor(string memory name_, uint256 version_, address subvaultFactory_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("Subvault", name_, version_);
        subvaultFactory = subvaultFactory_;
    }

    // View functionss

    function subvaults() public view returns (uint256) {
        return _rootVaultStorage().subvaults.length();
    }

    function subvaultAt(uint256 index) public view returns (address) {
        return _rootVaultStorage().subvaults.at(index);
    }

    function hasSubvault(address subvault) public view returns (bool) {
        return _rootVaultStorage().subvaults.contains(subvault);
    }

    function convertToShares(address asset, uint256 value) public view returns (uint256 shares) {
        uint256 priceD18 = ISharesModule(address(this)).depositOracle().getReport(asset).priceD18;
        if (priceD18 == 0) {
            return 0;
        }
        shares = Math.mulDiv(value, priceD18, 1 ether);
        if (shares > uint256(type(int256).max)) {
            revert("SubvaultModule: value exceeds int256 limit");
        }
        return shares;
    }

    function getSubvaultState(address subvault) public view returns (int256 limit, int256 balance) {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: not a valid subvault");
        limit = $.limits[subvault];
        balance = $.balances[subvault];
    }

    // Mutable functions

    function createSubvault(CreateSubvaultParams calldata initParams)
        external
        onlyRole(PermissionsLibrary.CREATE_SUBVAULT_ROLE)
        returns (address subvault)
    {
        requireFundamentalRole(initParams.owner, FundamentalRole.PROXY_OWNER);
        requireFundamentalRole(initParams.subvaultAdmin, FundamentalRole.SUBVAULT_ADMIN);
        subvault = IFactory(subvaultFactory).create(
            initParams.version, initParams.owner, abi.encode(initParams.subvaultAdmin, initParams.verifier)
        );
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        $.subvaults.add(subvault);
        $.limits[subvault] = initParams.limit;
    }

    function disconnectSubvault(address subvault) external onlyRole(PermissionsLibrary.DISCONNECT_SUBVAULT_ROLE) {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: subvault not found");
        $.subvaults.remove(subvault);
        delete $.balances[subvault];
        delete $.limits[subvault];
    }

    function reconnectSubvault(address subvault) external onlyRole(PermissionsLibrary.RECONNECT_SUBVAULT_ROLE) {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require(!$.subvaults.contains(subvault), "SubvaultModule: subvault already connected");
        require(IFactory(subvaultFactory).isEntity(subvault), "SubvaultModule: not a valid subvault");
        $.subvaults.add(subvault);
    }

    function pullAssets(address subvault, address asset, uint256 value)
        external
        onlyRole(PermissionsLibrary.PULL_LIQUIDITY_ROLE)
    {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        if (!$.subvaults.contains(subvault)) {
            revert("SubvaultModule: not a valid subvault");
        }
        ISubvaultModule(subvault).pullAssets(asset, address(this), value);
        $.balances[subvault] -= int256(convertToShares(asset, value));
    }

    function pushAssets(address subvault, address asset, uint256 value)
        external
        onlyRole(PermissionsLibrary.PUSH_LIQUIDITY_ROLE)
    {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        if (!$.subvaults.contains(subvault)) {
            revert("SubvaultModule: not a valid subvault");
        }

        int256 increment = int256(convertToShares(asset, value));
        if ($.balances[subvault] + increment > $.limits[subvault]) {
            revert("SubvaultModule: exceeds subvault limit");
        }

        $.balances[subvault] += increment;
        TransferLibrary.sendAssets(asset, subvault, value);
    }

    function setSubvaultLimit(address subvault, int256 limit)
        external
        onlyRole(PermissionsLibrary.SET_SUBVAULT_LIMIT_ROLE)
    {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: not a valid subvault");
        $.limits[subvault] = limit;
    }

    function applyCorrection(address subvault, int256 correction)
        external
        onlyRole(PermissionsLibrary.APPLY_CORRECTION_ROLE)
    {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: not a valid subvault");
        $.balances[subvault] += correction;
    }

    // Internal functions

    function _rootVaultStorage() private view returns (RootVaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
