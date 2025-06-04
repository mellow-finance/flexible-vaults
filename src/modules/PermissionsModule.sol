// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../permissions/BaseVerifier.sol";
import "./BaseModule.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

abstract contract PermissionsModule is BaseModule, AccessControlEnumerableUpgradeable {
    struct PermissionsModuleStorage {
        address verifier;
    }

    bytes32 private immutable _permissionsModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _permissionsModuleStorageSlot = SlotLibrary.getSlot("Permissions", name_, version_);
    }

    // View functions

    function verifier() public view returns (BaseVerifier) {
        return BaseVerifier(_permissionsModuleStorage().verifier);
    }

    // Internal functions

    function __PermissionsModule_init(address verifier_, address admin_) internal onlyInitializing {
        if (verifier_ == address(0)) {
            revert("PermissionsModule: zero guard address");
        }
        if (admin_ == address(0)) {
            revert("PermissionsModule: zero admin address");
        }
        _permissionsModuleStorage().verifier = verifier_;
        _grantRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE, admin_);
    }

    function _permissionsModuleStorage() private view returns (PermissionsModuleStorage storage $) {
        bytes32 slot = _permissionsModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
