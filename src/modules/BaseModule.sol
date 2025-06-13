// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract BaseModule is ContextUpgradeable {
    constructor() {
        _disableInitializers();
    }

    // Mutable functions

    receive() external payable {}
}
