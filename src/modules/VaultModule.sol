// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IVaultModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

abstract contract VaultModule is IVaultModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant CREATE_SUBVAULT_ROLE = keccak256("modules.VaultModule.CREATE_SUBVAULT_ROLE");
    bytes32 public constant DISCONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.DISCONNECT_SUBVAULT_ROLE");
    bytes32 public constant RECONNECT_SUBVAULT_ROLE = keccak256("modules.VaultModule.RECONNECT_SUBVAULT_ROLE");
    bytes32 public constant PULL_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PULL_LIQUIDITY_ROLE");
    bytes32 public constant PUSH_LIQUIDITY_ROLE = keccak256("modules.VaultModule.PUSH_LIQUIDITY_ROLE");
    bytes32 private immutable _subvaultModuleStorageSlot;

    address public immutable subvaultFactory;

    constructor(string memory name_, uint256 version_, address subvaultFactory_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("VaultModule", name_, version_);
        subvaultFactory = subvaultFactory_;
    }

    // View functionss

    function subvaults() public view returns (uint256) {
        return _vaultStorage().subvaults.length();
    }

    function subvaultAt(uint256 index) public view returns (address) {
        return _vaultStorage().subvaults.at(index);
    }

    function hasSubvault(address subvault) public view returns (bool) {
        return _vaultStorage().subvaults.contains(subvault);
    }

    function riskManager() public view returns (IRiskManager) {
        return IRiskManager(_vaultStorage().riskManager);
    }

    // Mutable functions

    function createSubvault(uint256 version, address owner, address subvaultAdmin, address verifier)
        external
        onlyRole(CREATE_SUBVAULT_ROLE)
        returns (address subvault)
    {
        requireFundamentalRole(owner, FundamentalRole.PROXY_OWNER);
        requireFundamentalRole(subvaultAdmin, FundamentalRole.SUBVAULT_ADMIN);
        subvault = IFactory(subvaultFactory).create(version, owner, abi.encode(subvaultAdmin, verifier, address(this)));
        VaultModuleStorage storage $ = _vaultStorage();
        $.subvaults.add(subvault);
    }

    function disconnectSubvault(address subvault) external onlyRole(DISCONNECT_SUBVAULT_ROLE) {
        VaultModuleStorage storage $ = _vaultStorage();
        if (!$.subvaults.contains(subvault)) {
            revert NotConnected(subvault);
        }
        $.subvaults.remove(subvault);
    }

    function reconnectSubvault(address subvault) external onlyRole(RECONNECT_SUBVAULT_ROLE) {
        VaultModuleStorage storage $ = _vaultStorage();
        if (!IFactory(subvaultFactory).isEntity(subvault)) {
            revert NotEntity(subvault);
        }
        if ($.subvaults.contains(subvault)) {
            revert AlreadyConnected(subvault);
        }
        $.subvaults.add(subvault);
    }

    function pullAssets(address subvault, address asset, uint256 value) external onlyRole(PULL_LIQUIDITY_ROLE) {
        riskManager().modifySubvaultBalance(subvault, asset, -int256(value));
        ISubvaultModule(subvault).pullAssets(asset, address(this), value);
    }

    function pushAssets(address subvault, address asset, uint256 value) external onlyRole(PUSH_LIQUIDITY_ROLE) {
        riskManager().modifySubvaultBalance(subvault, asset, int256(value));
        TransferLibrary.sendAssets(asset, subvault, value);
    }

    // Internal functions

    function __VaultModule_init(address riskManager_) internal onlyInitializing {
        _vaultStorage().riskManager = riskManager_;
    }

    function _vaultStorage() private view returns (VaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
