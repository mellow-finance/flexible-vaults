// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IBaseModule.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IACLModule is IAccessControlEnumerable {
    enum FundamentalRole {
        ADMIN,
        PROXY_OWNER,
        SUBVAULT_ADMIN
    }

    struct ACLModuleStorage {
        EnumerableSet.Bytes32Set supportedRoles;
        mapping(address account => uint256) fundamentalRoles;
    }

    function hasFundamentalRole(address account, FundamentalRole role) external view returns (bool);
    function requireFundamentalRole(address account, FundamentalRole role) external view;
    function supportedRoles() external view returns (uint256);
    function supportedRoleAt(uint256 index) external view returns (bytes32);
    function isSupportedRole(bytes32 role) external view returns (bool);

    // Mutable functions

    function grantFundamentalRole(FundamentalRole role, address account) external;
    function revokeFundamentalRole(FundamentalRole role, address account) external;
}
