// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract BaseModule is Initializable {
    constructor() {
        _disableInitializers();
    }

    // Mutable functions

    receive() external payable {}
}
