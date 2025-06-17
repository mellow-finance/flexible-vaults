// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISubvaultModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./BaseModule.sol";

abstract contract SubvaultModule is ISubvaultModule, BaseModule {
    bytes32 private immutable _subvaultModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _subvaultModuleStorageSlot = SlotLibrary.getSlot("Subvault", name_, version_);
    }

    function rootVault() public view returns (address) {
        return _subvaultModuleStorage().rootVault;
    }

    function pullAssets(address asset, address to, uint256 value) external {
        require(_msgSender() == rootVault(), "SubvaultModule: only root vault can pull liquidity");
        TransferLibrary.sendAssets(asset, to, value);
    }

    // Internal functions

    function __SubvaultModule_init(address rootVault_) internal onlyInitializing {
        _subvaultModuleStorage().rootVault = rootVault_;
    }

    function _subvaultModuleStorage() internal view returns (SubvaultModuleStorage storage $) {
        bytes32 slot = _subvaultModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
