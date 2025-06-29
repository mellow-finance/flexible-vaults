// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IBaseModule.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract BaseModule is IBaseModule, ContextUpgradeable {
    constructor() {
        _disableInitializers();
    }

    // View functions

    function getStorageAt(bytes32 slot) external pure returns (StorageSlot.Bytes32Slot memory) {
        return StorageSlot.getBytes32Slot(slot);
    }

    // Mutable functions

    receive() external payable {}
}
