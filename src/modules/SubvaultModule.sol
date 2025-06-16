// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISubvaultModule.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

abstract contract SubvaultModule is ContextUpgradeable {
    address public rootVault;

    function __SubvaultModule_init(address rootVault_) internal {
        rootVault = rootVault_;
    }

    function pullAssets(address asset, address to, uint256 value) external {
        require(_msgSender() == rootVault, "SubvaultModule: only root vault can pull liquidity");
        TransferLibrary.sendAssets(asset, to, value);
    }
}
