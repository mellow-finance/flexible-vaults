// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IBaseModule.sol";

abstract contract BaseModule is IBaseModule, ContextUpgradeable {
    constructor() {
        _disableInitializers();
    }

    // Mutable functions

    receive() external payable {}
}
