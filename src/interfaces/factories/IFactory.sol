// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IFactoryEntity.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IFactory is IFactoryEntity {
    error OutOfBounds(uint256 index);
    error BlacklistedVersion(uint256 version);
    error ImplementationAlreadyAccepted(address implementation);
    error ImplementationAlreadyProposed(address implementation);
    error ImplementationNotProposed(address implementation);

    struct FactoryStorage {
        EnumerableSet.AddressSet entities;
        EnumerableSet.AddressSet implementations;
        EnumerableSet.AddressSet proposals;
        mapping(uint256 version => bool) isBlacklisted;
    }

    // View functions

    function entities() external view returns (uint256);
    function entityAt(uint256 index) external view returns (address);
    function isEntity(address entity) external view returns (bool);
    function implementations() external view returns (uint256);
    function implementationAt(uint256 index) external view returns (address);
    function proposals() external view returns (uint256);
    function proposalAt(uint256 index) external view returns (address);
    function isBlacklisted(uint256 version) external view returns (bool);

    // Mutable functions
    function setBlacklistStatus(uint256 version, bool flag) external;
    function proposeImplementation(address implementation) external;
    function acceptProposedImplementation(address implementation) external;
    function computeAddress(uint256 version, address owner, bytes calldata initParams)
        external
        view
        returns (address instance);
    function create(uint256 version, address owner, bytes calldata initParams) external returns (address instance);
}
