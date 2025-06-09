// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "./ACLPermissionsModule.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract SubvaultFactoryModule is ACLPermissionsModule {
    struct SubvaultFactoryModuleStorage {
        address subvaultImplementation;
        uint256 subvaultsCount;
        mapping(uint256 index => address) subvaults;
    }

    bytes32 private immutable _factoryModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _factoryModuleStorageSlot = SlotLibrary.getSlot("Factory", name_, version_);
    }

    // View functions

    function subvaultImplementation() public view returns (address) {
        return _subvaultFactoryStorage().subvaultImplementation;
    }

    function subvaultAt(uint256 index) public view returns (address) {
        return _subvaultFactoryStorage().subvaults[index];
    }

    function subvaultsCount() public view returns (uint256) {
        return _subvaultFactoryStorage().subvaultsCount;
    }

    // Mutable functions

    function addSubvault() external onlyRole(PermissionsLibrary.ADD_SUVAULT_ROLE) returns (address subvault) {
        SubvaultFactoryModuleStorage storage $ = _subvaultFactoryStorage();
        subvault = Clones.clone($.subvaultImplementation);
        uint256 count = $.subvaultsCount;
        $.subvaults[count] = subvault;
        $.subvaultsCount = count + 1;
    }

    // Internal functions

    function _subvaultFactoryStorage() private view returns (SubvaultFactoryModuleStorage storage $) {
        bytes32 slot = _factoryModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
