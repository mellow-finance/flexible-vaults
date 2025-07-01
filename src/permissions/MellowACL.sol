// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/permissions/IMellowACL.sol";

import "../libraries/SlotLibrary.sol";

abstract contract MellowACL is IMellowACL, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 private immutable _mellowACLStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _mellowACLStorageSlot = SlotLibrary.getSlot("MellowACL", name_, version_);
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc IMellowACL
    function supportedRoles() external view returns (uint256) {
        return _mellowACLStorage().supportedRoles.length();
    }

    /// @inheritdoc IMellowACL
    function supportedRoleAt(uint256 index) external view returns (bytes32) {
        return _mellowACLStorage().supportedRoles.at(index);
    }

    /// @inheritdoc IMellowACL
    function hasSupportedRole(bytes32 role) external view returns (bool) {
        return _mellowACLStorage().supportedRoles.contains(role);
    }

    // Internal functions

    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._grantRole(role, account)) {
            if (_mellowACLStorage().supportedRoles.add(role)) {
                emit RoleAdded(role);
            }
            return true;
        }
        return false;
    }

    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (super._revokeRole(role, account)) {
            if (getRoleMemberCount(role) == 0) {
                _mellowACLStorage().supportedRoles.remove(role);
                emit RoleRemoved(role);
            }
            return true;
        }
        return false;
    }

    function _mellowACLStorage() private view returns (MellowACLStorage storage $) {
        bytes32 slot = _mellowACLStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
