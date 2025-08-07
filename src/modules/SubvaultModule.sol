// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISubvaultModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./BaseModule.sol";

abstract contract SubvaultModule is ISubvaultModule, BaseModule {
    bytes32 private immutable _subvaultModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("SubvaultModule", name_, version_);
    }

    // View functions

    /// @inheritdoc ISubvaultModule
    function vault() public view returns (address) {
        return _subvaultModuleStorage().vault;
    }

    // Mutable functions

    /// @inheritdoc ISubvaultModule
    function pullAssets(address asset, uint256 value) external nonReentrant {
        address caller = _msgSender();
        if (caller != vault()) {
            revert NotVault();
        }
        TransferLibrary.sendAssets(asset, caller, value);
        emit AssetsPulled(asset, caller, value);
    }

    // Internal functions

    function __SubvaultModule_init(address vault_) internal onlyInitializing {
        _subvaultModuleStorage().vault = vault_;
    }

    function _subvaultModuleStorage() internal view returns (SubvaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
