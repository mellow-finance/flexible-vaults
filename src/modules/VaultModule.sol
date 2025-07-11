// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IVaultModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

abstract contract VaultModule is IVaultModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IVaultModule
    bytes32 public constant CREATE_SUBVAULT_ROLE = keccak256("modules.VaultModule.CREATE_SUBVAULT_ROLE");
    /// @inheritdoc IVaultModule
    bytes32 public constant DISCONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.DISCONNECT_SUBVAULT_ROLE");
    /// @inheritdoc IVaultModule
    bytes32 public constant RECONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.RECONNECT_SUBVAULT_ROLE");
    /// @inheritdoc IVaultModule
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE");
    /// @inheritdoc IVaultModule
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE");

    /// @inheritdoc IVaultModule
    IFactory public immutable subvaultFactory;
    /// @inheritdoc IVaultModule
    IFactory public immutable verifierFactory;

    bytes32 private immutable _subvaultModuleStorageSlot;

    constructor(string memory name_, uint256 version_, address subvaultFactory_, address verifierFactory_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("VaultModule", name_, version_);
        subvaultFactory = IFactory(subvaultFactory_);
        verifierFactory = IFactory(verifierFactory_);
    }

    // View functionss

    /// @inheritdoc IVaultModule
    function subvaults() public view returns (uint256) {
        return _vaultStorage().subvaults.length();
    }

    /// @inheritdoc IVaultModule
    function subvaultAt(uint256 index) public view returns (address) {
        return _vaultStorage().subvaults.at(index);
    }

    /// @inheritdoc IVaultModule
    function hasSubvault(address subvault) public view returns (bool) {
        return _vaultStorage().subvaults.contains(subvault);
    }

    /// @inheritdoc IVaultModule
    function riskManager() public view returns (IRiskManager) {
        return IRiskManager(_vaultStorage().riskManager);
    }

    // Mutable functions

    /// @inheritdoc IVaultModule
    function createSubvault(uint256 version, address owner, address verifier)
        external
        onlyRole(CREATE_SUBVAULT_ROLE)
        nonReentrant
        returns (address subvault)
    {
        if (!verifierFactory.isEntity(verifier)) {
            revert NotEntity(verifier);
        }
        if (address(IVerifier(verifier).vault()) != address(this)) {
            revert Forbidden();
        }
        subvault = subvaultFactory.create(version, owner, abi.encode(verifier, address(this)));
        _vaultStorage().subvaults.add(subvault);
        emit SubvaultCreated(subvault, version, owner, verifier);
    }

    /// @inheritdoc IVaultModule
    function disconnectSubvault(address subvault) external onlyRole(DISCONNECT_SUBVAULT_ROLE) {
        VaultModuleStorage storage $ = _vaultStorage();
        if (!$.subvaults.remove(subvault)) {
            revert NotConnected(subvault);
        }
        emit SubvaultDisconnected(subvault);
    }

    /// @inheritdoc IVaultModule
    function reconnectSubvault(address subvault) external onlyRole(RECONNECT_SUBVAULT_ROLE) {
        VaultModuleStorage storage $ = _vaultStorage();
        if (!subvaultFactory.isEntity(subvault)) {
            revert NotEntity(subvault);
        }
        if (ISubvaultModule(subvault).vault() != address(this)) {
            revert InvalidSubvault(subvault);
        }
        IVerifier verifier = IVerifierModule(subvault).verifier();
        if (!verifierFactory.isEntity(address(verifier))) {
            revert NotEntity(address(verifier));
        }
        if (address(verifier.vault()) != address(this)) {
            revert Forbidden();
        }
        if (!$.subvaults.add(subvault)) {
            revert AlreadyConnected(subvault);
        }
        emit SubvaultReconnected(subvault, address(verifier));
    }

    /// @inheritdoc IVaultModule
    function pullAssets(address subvault, address asset, uint256 value)
        external
        onlyRole(PULL_LIQUIDITY_ROLE)
        nonReentrant
    {
        _pullAssets(subvault, asset, value);
    }

    /// @inheritdoc IVaultModule
    function pushAssets(address subvault, address asset, uint256 value)
        external
        onlyRole(PUSH_LIQUIDITY_ROLE)
        nonReentrant
    {
        _pushAssets(subvault, asset, value);
    }

    /// @inheritdoc IVaultModule
    function hookPullAssets(address subvault, address asset, uint256 value) external {
        if (_msgSender() != address(this)) {
            revert Forbidden();
        }
        _pullAssets(subvault, asset, value);
    }

    /// @inheritdoc IVaultModule
    function hookPushAssets(address subvault, address asset, uint256 value) external {
        if (_msgSender() != address(this)) {
            revert Forbidden();
        }
        _pushAssets(subvault, asset, value);
    }

    // Internal functions

    function _pullAssets(address subvault, address asset, uint256 value) internal {
        riskManager().modifySubvaultBalance(subvault, asset, -int256(value));
        ISubvaultModule(subvault).pullAssets(asset, value);
        emit AssetsPulled(asset, subvault, value);
    }

    function _pushAssets(address subvault, address asset, uint256 value) internal {
        riskManager().modifySubvaultBalance(subvault, asset, int256(value));
        TransferLibrary.sendAssets(asset, subvault, value);
        emit AssetsPushed(asset, subvault, value);
    }

    function __VaultModule_init(address riskManager_) internal onlyInitializing {
        if (riskManager_ == address(0)) {
            revert ZeroAddress();
        }
        _vaultStorage().riskManager = riskManager_;
    }

    function _vaultStorage() private view returns (VaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
