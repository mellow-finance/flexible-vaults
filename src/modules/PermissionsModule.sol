// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../permissions/Verifier.sol";

import "./ACLPermissionsModule.sol";
import "./BaseModule.sol";

abstract contract PermissionsModule is BaseModule, ACLPermissionsModule {
    struct PermissionsModuleStorage {
        address verifier;
    }

    bytes32 private immutable _permissionsModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _permissionsModuleStorageSlot = SlotLibrary.getSlot("Permissions", name_, version_);
    }

    // View functions

    function verifier() public view returns (Verifier) {
        return Verifier(_permissionsModuleStorage().verifier);
    }

    // Internal functions

    function __PermissionsModule_init(address admin_, address verifier_) internal onlyInitializing {
        if (verifier_ == address(0)) {
            revert("PermissionsModule: zero guard address");
        }
        _permissionsModuleStorage().verifier = verifier_;
        __ACLPermissionsModule_init(admin_);
    }

    function _permissionsModuleStorage() private view returns (PermissionsModuleStorage storage $) {
        bytes32 slot = _permissionsModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
