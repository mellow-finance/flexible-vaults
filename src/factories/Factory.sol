// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Factory is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct FactoryStorage {
        EnumerableSet.AddressSet entities;
        EnumerableSet.AddressSet implementation;
        EnumerableSet.AddressSet proposals;
        mapping(uint256 version => bool) isBlacklisted;
    }

    bytes32 private immutable _factoryStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _disableInitializers();
        _factoryStorageSlot = keccak256(abi.encodePacked("Factory", name_, version_));
    }

    // View functions

    function entities() external view returns (uint256) {
        return _factoryStorage().entities.length();
    }

    function entityAt(uint256 index) external view returns (address) {
        return _factoryStorage().entities.at(index);
    }

    function isEntity(address entity) external view returns (bool) {
        return _factoryStorage().entities.contains(entity);
    }

    function implementations() external view returns (uint256) {
        return _factoryStorage().implementation.length();
    }

    function implementationAt(uint256 index) external view returns (address) {
        return _factoryStorage().implementation.at(index);
    }

    function proposals() external view returns (uint256) {
        return _factoryStorage().proposals.length();
    }

    function proposalAt(uint256 index) external view returns (address) {
        return _factoryStorage().proposals.at(index);
    }

    function isBlacklisted(uint256 version) external view returns (bool) {
        return _factoryStorage().isBlacklisted[version];
    }

    // Mutable functions

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
    }

    function setBlacklistStatus(uint256 version, bool flag) external onlyOwner {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementation.length()) {
            revert("Factory: version out of bounds");
        }
        $.isBlacklisted[version] = flag;
    }

    function proposeImplementation(address implementation) external {
        FactoryStorage storage $ = _factoryStorage();
        require(!$.entities.contains(implementation), "Factory: entity already exists");
        require(!$.proposals.contains(implementation), "Factory: proposal already exists");
        $.proposals.add(implementation);
    }

    function acceptProposedImplementation(address implementation) external onlyOwner {
        FactoryStorage storage $ = _factoryStorage();
        require($.proposals.contains(implementation), "Factory: proposal does not exist");
        $.proposals.remove(implementation);
        $.implementation.add(implementation);
    }

    function create(uint256 version, address owner, bytes calldata initParams, bytes32 salt)
        external
        returns (address instance)
    {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementation.length()) {
            revert("Factory: version out of bounds");
        }
        if ($.isBlacklisted[version]) {
            revert("Factory: version is blacklisted");
        }
        address implementation = $.implementation.at(version);
        salt = keccak256(abi.encodePacked(version, owner, initParams, salt, $.entities.length()));
        instance = address(
            new TransparentUpgradeableProxy{salt: salt}(
                implementation, owner, abi.encodeWithSignature("initialize(bytes memory)", initParams)
            )
        );
        $.entities.add(instance);
    }

    // Internal functions

    function _factoryStorage() private view returns (FactoryStorage storage fs) {
        bytes32 slot = _factoryStorageSlot;
        assembly {
            fs.slot := slot
        }
    }
}
