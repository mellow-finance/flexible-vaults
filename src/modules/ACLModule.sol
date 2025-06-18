// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IACLModule.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";

import "./BaseModule.sol";

abstract contract ACLModule is IACLModule, BaseModule, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 private immutable _aclModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _aclModuleStorageSlot = SlotLibrary.getSlot("ACL", name_, version_);
    }

    // View functions

    function hasFundamentalRole(address account, FundamentalRole role) public view returns (bool) {
        return _aclModuleStorage().fundamentalRoles[account] & (1 << uint256(role)) != 0;
    }

    function requireFundamentalRole(address account, FundamentalRole role) public view {
        if (!hasFundamentalRole(account, role)) {
            revert("ACLModule: account does not have the required fundamental role");
        }
    }

    function supportedRoles() public view returns (uint256) {
        return _aclModuleStorage().supportedRoles.length();
    }

    function supportedRoleAt(uint256 index) public view returns (bytes32) {
        return _aclModuleStorage().supportedRoles.at(index);
    }

    function isSupportedRole(bytes32 role) public view returns (bool) {
        return _aclModuleStorage().supportedRoles.contains(role);
    }

    // Mutable functions

    function grantFundamentalRole(address account, FundamentalRole role)
        external
        onlyRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE)
    {
        _grantFundamentalRole(account, role);
    }

    function revokeFundamentalRole(address account, FundamentalRole role)
        external
        onlyRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE)
    {
        _revokeFundamentalRole(account, role);
    }

    // Internal functions

    function __ACLModule_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert("ACLModule: zero admin address");
        }
        _grantFundamentalRole(admin_, FundamentalRole.ADMIN);
        _grantRole(PermissionsLibrary.DEFAULT_ADMIN_ROLE, admin_);
    }

    function _grantFundamentalRole(address account, FundamentalRole role) internal virtual {
        if (account == address(0)) {
            revert("ACLModule: zero account address");
        }
        _aclModuleStorage().fundamentalRoles[account] |= (1 << uint256(role));
    }

    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (role == DEFAULT_ADMIN_ROLE) {
            requireFundamentalRole(account, FundamentalRole.ADMIN);
        }
        if (super._grantRole(role, account)) {
            _aclModuleStorage().supportedRoles.add(role);
            return true;
        }
        return false;
    }

    function _revokeFundamentalRole(address account, FundamentalRole role) internal virtual {
        if (account == address(0)) {
            revert("ACLModule: zero account address");
        }
        _aclModuleStorage().fundamentalRoles[account] &= ~(1 << uint256(role));
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
