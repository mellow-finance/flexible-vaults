// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title IFactory
/// @notice Interface for a factory that manages deployable upgradeable proxies and implementation governance.
interface IFactory is IFactoryEntity {
    /// @notice Thrown when attempting to access an index outside the valid range.
    error OutOfBounds(uint256 index);

    /// @notice Thrown when trying to use an implementation version that is blacklisted.
    error BlacklistedVersion(uint256 version);

    /// @notice Thrown when an implementation is already in the accepted list.
    error ImplementationAlreadyAccepted(address implementation);

    /// @notice Thrown when an implementation has already been proposed.
    error ImplementationAlreadyProposed(address implementation);

    /// @notice Thrown when attempting to accept an implementation that was never proposed.
    error ImplementationNotProposed(address implementation);

    /// @dev Internal storage structure for tracking factory state.
    struct FactoryStorage {
        EnumerableSet.AddressSet entities; // Set of deployed upgradeable proxies
        EnumerableSet.AddressSet implementations; // Set of accepted implementation addresses
        EnumerableSet.AddressSet proposals; // Set of currently proposed (but not yet accepted) implementations
        mapping(uint256 version => bool) isBlacklisted; // Tracks whether a given version is blacklisted
    }

    /// @notice Returns the total number of deployed entities (proxies).
    function entities() external view returns (uint256);

    /// @notice Returns the address of the deployed entity at a given index.
    function entityAt(uint256 index) external view returns (address);

    /// @notice Returns whether the given address is a deployed entity.
    function isEntity(address entity) external view returns (bool);

    /// @notice Returns the total number of accepted implementation contracts.
    function implementations() external view returns (uint256);

    /// @notice Returns the implementation address at the given index.
    function implementationAt(uint256 index) external view returns (address);

    /// @notice Returns the number of currently proposed (pending) implementations.
    function proposals() external view returns (uint256);

    /// @notice Returns the address of a proposed implementation at a given index.
    function proposalAt(uint256 index) external view returns (address);

    /// @notice Returns whether the given implementation version is blacklisted.
    function isBlacklisted(uint256 version) external view returns (bool);

    /// @notice Updates the blacklist status for a specific implementation version.
    /// @param version The version index to update.
    /// @param flag True to blacklist, false to unblacklist.
    function setBlacklistStatus(uint256 version, bool flag) external;

    /// @notice Proposes a new implementation for future deployment.
    /// @param implementation The address of the proposed implementation contract.
    function proposeImplementation(address implementation) external;

    /// @notice Approves a previously proposed implementation, allowing it to be used for deployments.
    /// @param implementation The address of the proposed implementation to approve.
    function acceptProposedImplementation(address implementation) external;

    /// @notice Deploys a new TransparentUpgradeableProxy using an accepted implementation.
    /// @param version The version index of the implementation to use.
    /// @param owner The address that will become the owner of the proxy.
    /// @param initParams Calldata to be passed for initialization of the new proxy instance.
    /// @return instance The address of the newly deployed proxy contract.
    function create(uint256 version, address owner, bytes calldata initParams) external returns (address instance);

    /// @notice Emitted when the blacklist status of a version is updated.
    event SetBlacklistStatus(uint256 version, bool flag);

    /// @notice Emitted when a new implementation is proposed.
    event ProposeImplementation(address implementation);

    /// @notice Emitted when a proposed implementation is accepted.
    event AcceptProposedImplementation(address implementation);

    /// @notice Emitted when a new proxy instance is successfully deployed.
    event Created(address indexed instance, uint256 indexed version, address indexed owner, bytes initParams);
}
