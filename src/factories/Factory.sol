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

    /// @inheritdoc IFactory
    function entities() external view returns (uint256) {
        return _factoryStorage().entities.length();
    }

    /// @inheritdoc IFactory
    function entityAt(uint256 index) external view returns (address) {
        return _factoryStorage().entities.at(index);
    }

    /// @inheritdoc IFactory
    function isEntity(address entity) external view returns (bool) {
        return _factoryStorage().entities.contains(entity);
    }

    /// @inheritdoc IFactory
    function implementations() external view returns (uint256) {
        return _factoryStorage().implementations.length();
    }

    /// @inheritdoc IFactory
    function implementationAt(uint256 index) external view returns (address) {
        return _factoryStorage().implementations.at(index);
    }

    /// @inheritdoc IFactory
    function proposals() external view returns (uint256) {
        return _factoryStorage().proposals.length();
    }

    /// @inheritdoc IFactory
    function proposalAt(uint256 index) external view returns (address) {
        return _factoryStorage().proposals.at(index);
    }

    /// @inheritdoc IFactory
    function isBlacklisted(uint256 version) external view returns (bool) {
        return _factoryStorage().isBlacklisted[version];
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        address owner_ = abi.decode(data, (address));
        __Ownable_init(owner_);
        emit Initialized(data);
    }

    /// @inheritdoc IFactory
    function setBlacklistStatus(uint256 version, bool flag) external onlyOwner {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementations.length()) {
            revert OutOfBounds(version);
        }
        $.isBlacklisted[version] = flag;
        emit SetBlacklistStatus(version, flag);
    }

    /// @inheritdoc IFactory
    function proposeImplementation(address implementation) external {
        FactoryStorage storage $ = _factoryStorage();
        if ($.implementations.contains(implementation)) {
            revert ImplementationAlreadyAccepted(implementation);
        }
        if ($.proposals.contains(implementation)) {
            revert ImplementationAlreadyProposed(implementation);
        }
        $.proposals.add(implementation);
        emit ProposeImplementation(implementation);
    }

    /// @inheritdoc IFactory
    function acceptProposedImplementation(address implementation) external onlyOwner {
        FactoryStorage storage $ = _factoryStorage();
        if (!$.proposals.contains(implementation)) {
            revert ImplementationNotProposed(implementation);
        }
        $.proposals.remove(implementation);
        $.implementations.add(implementation);
        emit AcceptProposedImplementation(implementation);
    }

    /// @inheritdoc IFactory
    function create(uint256 version, address owner, bytes calldata initParams) external returns (address instance) {
        FactoryStorage storage $ = _factoryStorage();
        if (version >= $.implementations.length()) {
            revert OutOfBounds(version);
        }
        if ($.isBlacklisted[version]) {
            revert BlacklistedVersion(version);
        }
        address implementation = $.implementations.at(version);
        bytes32 salt = keccak256(abi.encodePacked(version, owner, initParams, $.entities.length()));
        instance = address(
            new TransparentUpgradeableProxy{salt: salt}(
                implementation, owner, abi.encodeCall(IFactoryEntity.initialize, (initParams))
            )
        );
        $.entities.add(instance);
        emit Created(instance, version, owner, initParams);
    }

    // Internal functions

    function _factoryStorage() private view returns (FactoryStorage storage fs) {
        bytes32 slot = _factoryStorageSlot;
        assembly {
            fs.slot := slot
        }
    }
}
