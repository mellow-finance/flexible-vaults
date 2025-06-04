// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";

contract BaseVault is CallModule {
    constructor(string memory name_, uint256 version_) CallModule() PermissionsModule(name_, version_) {
        _disableInitializers();
    }

    function initialize(address guard_, address admin_) external initializer {
        __PermissionsModule_init(guard_, admin_);
        emit VaultInitialized(guard_, admin_);
    }

    event VaultInitialized(address indexed guard, address indexed admin);
}
