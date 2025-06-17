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

    // View functions

    function subvaults() public view returns (uint256) {
        return _rootVaultStorage().subvaults.length();
    }

    function subvaultAt(uint256 index) public view returns (address) {
        return _rootVaultStorage().subvaults.at(index);
    }

    function isSubvault(address subvault) public view returns (bool) {
        return _rootVaultStorage().subvaults.contains(subvault);
    }

    function convertToShares(address asset, uint256 value) public view returns (uint256) {
        uint256 priceD18 = ISharesModule(address(this)).depositOracle().getReport(asset).priceD18;
        if (priceD18 == 0) {
            return 0;
        }
        return Math.mulDiv(value, priceD18, 1 ether);
    }

    // Mutable functions

    function createSubvault(uint256 version, address owner, address subvaultAdmin, address verifier, bytes32 salt)
        external
        onlyRole(PermissionsLibrary.CREATE_SUBVAULT_ROLE)
        returns (address subvault)
    {
        requireFundamentalRole(owner, FundamentalRole.PROXY_OWNER);
        requireFundamentalRole(subvaultAdmin, FundamentalRole.SUBVAULT_ADMIN);
        subvault = IFactory(subvaultFactory).create(version, owner, abi.encode(subvaultAdmin, verifier), salt);
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        $.subvaults.add(subvault);
    }

    function disconnectSubvault(address subvault) external onlyRole(PermissionsLibrary.DISCONNECT_SUBVAULT_ROLE) {
        RootVaultModuleStorage storage $ = _rootVaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: subvault not found");
        $.subvaults.remove(subvault);
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
        if ($.balances[subvault] + increment > int256($.limits[subvault])) {
            revert("SubvaultModule: exceeds subvault limit");
        }

        $.balances[subvault] += increment;
        TransferLibrary.sendAssets(asset, subvault, value);
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
