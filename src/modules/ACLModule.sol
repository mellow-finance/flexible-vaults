// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IACLModule.sol";

import "../libraries/SlotLibrary.sol";

import "../permissions/MellowACL.sol";
import "./BaseModule.sol";

abstract contract ACLModule is IACLModule, BaseModule, MellowACL {
    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    // Internal functions

    function __ACLModule_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert ZeroAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }
}
