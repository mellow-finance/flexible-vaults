// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IBaseModule.sol";

abstract contract BaseModule is IBaseModule, ContextUpgradeable, ReentrancyGuardUpgradeable {
    constructor() {
        _disableInitializers();
    }

    // View functions

    /// @inheritdoc IBaseModule
    function getStorageAt(bytes32 slot) external pure returns (StorageSlot.Bytes32Slot memory) {
        return StorageSlot.getBytes32Slot(slot);
    }

    // Mutable functions

    receive() external payable {}

    /// Internal functions

    function __BaseModule_init() internal onlyInitializing {
        __Context_init();
        __ReentrancyGuard_init();
    }
}
