// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/factories/IFactory.sol";

import "../libraries/SlotLibrary.sol";

contract Factory is IFactory, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _factoryStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _factoryStorageSlot = SlotLibrary.getSlot("Factory", name_, version_);
        _disableInitializers();
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
        return _factoryStorage().implementations.length();
    }

    function implementationAt(uint256 index) external view returns (address) {
        return _factoryStorage().implementations.at(index);
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
        if (version >= $.implementations.length()) {
            revert("Factory: version out of bounds");
        }
        $.isBlacklisted[version] = flag;
    }

    function proposeImplementation(address implementation) external {
        FactoryStorage storage $ = _factoryStorage();
        require(!$.implementations.contains(implementation), "Factory: entity already exists");
        require(!$.proposals.contains(implementation), "Factory: proposal already exists");
        $.proposals.add(implementation);
    }

    function acceptProposedImplementation(address implementation) external onlyOwner {
        FactoryStorage storage $ = _factoryStorage();
        require($.proposals.contains(implementation), "Factory: proposal does not exist");
        $.proposals.remove(implementation);
        $.implementations.add(implementation);
    }

    function computeAddress(uint256 version, address owner, bytes calldata initParams)
        external
        view
        returns (address instance)
    {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementations.length()) {
            return address(0);
        }
        if ($.isBlacklisted[version]) {
            return address(0);
        }
        address implementation = $.implementations.at(version);
        bytes32 salt = keccak256(abi.encodePacked(version, owner, initParams, $.entities.length()));
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implementation, owner, abi.encodeCall(IFactoryEntity.initialize, (initParams)))
                )
            )
        );
    }

    function create(uint256 version, address owner, bytes calldata initParams) external returns (address instance) {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementations.length()) {
            revert("Factory: version out of bounds");
        }
        if ($.isBlacklisted[version]) {
            revert("Factory: version is blacklisted");
        }
        address implementation = $.implementations.at(version);
        bytes32 salt = keccak256(abi.encodePacked(version, owner, initParams, $.entities.length()));
        instance = address(
            new TransparentUpgradeableProxy{salt: salt}(
                implementation, owner, abi.encodeCall(IFactoryEntity.initialize, (initParams))
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
