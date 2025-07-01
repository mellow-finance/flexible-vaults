// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IACLModule.sol";

import "../libraries/SlotLibrary.sol";

import "../permissions/MellowACL.sol";
import "./BaseModule.sol";

abstract contract ACLModule is IACLModule, BaseModule, MellowACL {
    bytes32 private immutable _aclModuleStorageSlot;

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {
        _aclModuleStorageSlot = SlotLibrary.getSlot("ACLModule", name_, version_);
    }

    // View functions

    /// @inheritdoc IACLModule
    function hasFundamentalRole(FundamentalRole role, address account) public view returns (bool) {
        return _aclModuleStorage().fundamentalRoles[account] & (1 << uint256(role)) != 0;
    }

    /// @inheritdoc IACLModule
    function requireFundamentalRole(FundamentalRole role, address account) public view {
        if (!hasFundamentalRole(role, account)) {
            revert Forbidden();
        }
    }

    // Mutable functions

    /// @inheritdoc IACLModule
    function grantFundamentalRole(FundamentalRole role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantFundamentalRole(role, account);
    }

    /// @inheritdoc IACLModule
    function revokeFundamentalRole(FundamentalRole role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeFundamentalRole(role, account);
    }

    // Internal functions

    function __ACLModule_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert ZeroAddress();
        }
        _grantFundamentalRole(FundamentalRole.ADMIN, admin_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    function _grantFundamentalRole(FundamentalRole role, address account) internal virtual {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        _aclModuleStorage().fundamentalRoles[account] |= (1 << uint256(role));
        emit FundamentalRoleGranted(role, account);
    }

    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (role == DEFAULT_ADMIN_ROLE) {
            requireFundamentalRole(FundamentalRole.ADMIN, account);
        }
        return super._grantRole(role, account);
    }

    function _revokeFundamentalRole(FundamentalRole role, address account) internal virtual {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        _aclModuleStorage().fundamentalRoles[account] &= ~(1 << uint256(role));
        emit FundamentalRoleRevoked(role, account);
    }

    function _aclModuleStorage() private view returns (ACLModuleStorage storage $) {
        bytes32 slot = _aclModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
