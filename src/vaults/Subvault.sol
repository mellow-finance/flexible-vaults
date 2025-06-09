// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";
import "../modules/PermissionsModule.sol";

contract Vault is CallModule {
    constructor(string memory name_, uint256 version_) PermissionsModule(name_, version_) {}

    function initialize(address admin_, address verifier_) external initializer {
        __PermissionsModule_init(admin_, verifier_);
    }
}
