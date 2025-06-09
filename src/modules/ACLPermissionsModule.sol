// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "./BaseModule.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

abstract contract ACLPermissionsModule is BaseModule, AccessControlEnumerableUpgradeable {
    // Internal functions
    function __ACLPermissionsModule_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert("PermissionsModule: zero admin address");
        }
        _grantRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE, admin_);
    }
}
