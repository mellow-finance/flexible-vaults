// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "./BaseModule.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract ACLModule is BaseModule, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct ACLModuleStorage {
        EnumerableSet.Bytes32Set supportedRoles;
    }

    bytes32 private immutable _aclModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _aclModuleStorageSlot = SlotLibrary.getSlot("ACL", name_, version_);
    }

    // View functions

    function supportedRoles() public view returns (uint256) {
        return _aclModuleStorage().supportedRoles.length();
    }

    function supportedRoleAt(uint256 index) public view returns (bytes32) {
        return _aclModuleStorage().supportedRoles.at(index);
    }

    function isSupportedRole(bytes32 role) public view returns (bool) {
        return _aclModuleStorage().supportedRoles.contains(role);
    }

    // Internal functions
    function __ACLModule_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert("ACLModule: zero admin address");
        }
        _grantRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE, admin_);
    }

    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._grantRole(role, account)) {
            _aclModuleStorage().supportedRoles.add(role);
            return true;
        }
        return false;
    }

    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._revokeRole(role, account)) {
            if (getRoleMemberCount(role) == 0) {
                _aclModuleStorage().supportedRoles.remove(role);
            }
            return true;
        }
        return false;
    }

    function _aclModuleStorage() private view returns (ACLModuleStorage storage $) {
        bytes32 slot = _aclModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
