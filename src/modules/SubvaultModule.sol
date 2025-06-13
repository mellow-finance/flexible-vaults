// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../factories/Factory.sol";
import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "./ACLModule.sol";

abstract contract SubvaultModule is ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct SubvaultModuleStorage {
        EnumerableSet.AddressSet subvaults;
    }

    bytes32 private immutable _subvaultModuleStorageSlot;
    address public immutable subvaultFactory;

    constructor(string memory name_, uint256 version_, address subvaultFactory_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("Subvault", name_, version_);
        subvaultFactory = subvaultFactory_;
    }

    // View functions

    function subvaults() external view returns (uint256) {
        return _subvaultStorage().subvaults.length();
    }

    function subvaultAt(uint256 index) external view returns (address) {
        return _subvaultStorage().subvaults.at(index);
    }

    function isSubvault(address subvault) external view returns (bool) {
        return _subvaultStorage().subvaults.contains(subvault);
    }

    // Mutable functions

    function createSubvault(uint256 version, address owner, address subvaultAdmin, address verifier, bytes32 salt)
        external
        onlyRole(PermissionsLibrary.CREATE_SUBVAULT_ROLE)
        returns (address subvault)
    {
        requireFundamentalRole(owner, FundamentalRole.PROXY_OWNER);
        requireFundamentalRole(subvaultAdmin, FundamentalRole.SUBVAULT_ADMIN);
        subvault = Factory(subvaultFactory).create(version, owner, abi.encode(subvaultAdmin, verifier), salt);
        SubvaultModuleStorage storage $ = _subvaultStorage();
        $.subvaults.add(subvault);
    }

    function disconnectSubvault(address subvault) external onlyRole(PermissionsLibrary.DISCONNECT_SUBVAULT_ROLE) {
        SubvaultModuleStorage storage $ = _subvaultStorage();
        require($.subvaults.contains(subvault), "SubvaultModule: subvault not found");
        $.subvaults.remove(subvault);
    }

    function reconnectSubvault(address subvault) external onlyRole(PermissionsLibrary.RECONNECT_SUBVAULT_ROLE) {
        SubvaultModuleStorage storage $ = _subvaultStorage();
        require(!$.subvaults.contains(subvault), "SubvaultModule: subvault already connected");
        require(Factory(subvaultFactory).isEntity(subvault), "SubvaultModule: not a valid subvault");
        $.subvaults.add(subvault);
    }

    // Internal functions

    function _subvaultStorage() private view returns (SubvaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
