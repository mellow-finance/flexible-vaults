// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/modules/ACLModule.sol";

contract MockACLModule is ACLModule {
    constructor(string memory name_, uint256 version_) ACLModule(name_, version_) {}

    function initialize(bytes calldata initParams) external initializer {
        (address vault_) = abi.decode(initParams, (address));
        __ACLModule_init(vault_);
    }

    function test() external {}
}
