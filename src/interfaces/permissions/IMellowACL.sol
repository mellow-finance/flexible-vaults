// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

interface IMellowACL is IAccessControlEnumerable {
    struct MellowACLStorage {
        EnumerableSet.Bytes32Set supportedRoles;
    }

    function supportedRoles() external view returns (uint256);

    function supportedRoleAt(uint256 index) external view returns (bytes32);

    function hasSupportedRole(bytes32 role) external view returns (bool);
}
