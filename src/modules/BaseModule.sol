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

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // Mutable functions

    receive() external payable {}

    // Internal functions

    function __BaseModule_init() internal onlyInitializing {
        __ReentrancyGuard_init();
    }
}
