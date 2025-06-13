// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "./ACLModule.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract SubvaultModule is ACLModule {
    struct SubvaultModuleStorage {
        address subvaultImplementation;
        uint256 subvaultsCount;
        mapping(uint256 index => address) subvaults;
    }

    bytes32 private immutable _subvaultModuleStorageSlot;
    address public immutable subvaultFactory;

    constructor(string memory name_, uint256 version_, address subvaultFactory_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("Factory", name_, version_);
        subvaultFactory = subvaultFactory_;
    }

    // View functions

    // Mutable functions

    // function createSubvault() external onlyRole(PermissionsLibrary.CREATE_SUBVAULT_ROLE) returns (address subvault) {

    // }

    // function setSubvaultLimits(uint256 subvaultIndex, uint256 limit) external {

    // }

    // Internal functions

    function _subvaultStorage() private view returns (SubvaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
