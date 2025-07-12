// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title IFactory
/// @notice Interface for a factory managing deployable upgradeable proxies and implementation proposals.
interface IFactory is IFactoryEntity {
    /// @notice Thrown when accessing an index that exceeds bounds.
    error OutOfBounds(uint256 index);

    /// @notice Thrown when trying to use a version that has been blacklisted.
    error BlacklistedVersion(uint256 version);

    /// @notice Thrown when an implementation is already accepted.
    error ImplementationAlreadyAccepted(address implementation);

    /// @notice Thrown when an implementation has already been proposed.
    error ImplementationAlreadyProposed(address implementation);

    /// @notice Thrown when an implementation has not been proposed yet.
    error ImplementationNotProposed(address implementation);

    /// @dev Storage struct used internally to track factory state.
    struct FactoryStorage {
        EnumerableSet.AddressSet entities;
        EnumerableSet.AddressSet implementations;
        EnumerableSet.AddressSet proposals;
        mapping(uint256 => bool) isBlacklisted;
    }

    // View functions

    /// @notice Returns the total number of deployed instances.
    function entities() external view returns (uint256);

    /// @notice Returns the address of an entity at a specific index.
    function entityAt(uint256 index) external view returns (address);

    /// @notice Checks whether an address is a registered entity.
    function isEntity(address entity) external view returns (bool);

    /// @notice Returns the total number of accepted implementations.
    function implementations() external view returns (uint256);

    /// @notice Returns the implementation address at a given index.
    function implementationAt(uint256 index) external view returns (address);

    /// @notice Returns the number of currently proposed (unaccepted) implementations.
    function proposals() external view returns (uint256);

    /// @notice Returns the proposed implementation address at a given index.
    function proposalAt(uint256 index) external view returns (address);

    /// @notice Checks if a given version is blacklisted.
    function isBlacklisted(uint256 version) external view returns (bool);

    // Mutable functions

    /// @notice Updates blacklist status of a specific implementation version.
    /// @param version The implementation version index.
    /// @param flag Whether the version should be blacklisted or not.
    function setBlacklistStatus(uint256 version, bool flag) external;

    /// @notice Proposes a new implementation for approval.
    /// @param implementation Address of the new implementation contract.
    function proposeImplementation(address implementation) external;

    /// @notice Accepts a previously proposed implementation.
    /// @param implementation Address of the proposed implementation to approve.
    function acceptProposedImplementation(address implementation) external;

    /// @notice Creates a new upgradeable proxy instance using a registered implementation version.
    /// @param version Index of the accepted implementation version.
    /// @param owner Address that will become the admin of the proxy.
    /// @param initParams Calldata used for initializing the proxy contract.
    /// @return instance The address of the newly deployed contract.
    function create(uint256 version, address owner, bytes calldata initParams) external returns (address instance);

    // Events

    /// @notice Emitted when blacklist status is changed for a version.
    event SetBlacklistStatus(uint256 version, bool flag);

    /// @notice Emitted when a new implementation is proposed.
    event ProposeImplementation(address implementation);

    /// @notice Emitted when a proposed implementation is accepted.
    event AcceptProposedImplementation(address implementation);

    /// @notice Emitted when a new proxy instance is created.
    event Created(address instance, uint256 version, address owner, bytes initParams);
}
