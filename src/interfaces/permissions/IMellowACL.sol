// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

/// @notice Interface for the MellowACL contract, which extends OpenZeppelin's AccessControlEnumerable
/// @dev Adds tracking of which roles are actively in use (i.e., assigned to at least one address)
interface IMellowACL is IAccessControlEnumerable {
    /// @notice Storage layout used to track actively assigned roles
    struct MellowACLStorage {
        EnumerableSet.Bytes32Set supportedRoles; // Set of roles that have at least one assigned member
    }

    /// @notice Returns the total number of unique roles that are currently assigned
    function supportedRoles() external view returns (uint256);

    /// @notice Returns the role at the specified index in the set of active roles
    /// @param index Index within the supported role set
    /// @return role The bytes32 identifier of the role
    function supportedRoleAt(uint256 index) external view returns (bytes32);

    /// @notice Checks whether a given role is currently active (i.e., has at least one member)
    /// @param role The bytes32 identifier of the role to check
    /// @return isActive True if the role has any members assigned
    function hasSupportedRole(bytes32 role) external view returns (bool);

    /// @notice Emitted when a new role is granted for the first time
    event RoleAdded(bytes32 indexed role);

    /// @notice Emitted when a role loses its last member
    event RoleRemoved(bytes32 indexed role);
}
