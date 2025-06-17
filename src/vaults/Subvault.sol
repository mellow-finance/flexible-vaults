// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";
import "../modules/SubvaultModule.sol";
import "../modules/VerifierModule.sol";

contract Subvault is CallModule, SubvaultModule {
    constructor(string memory name_, uint256 version_)
        VerifierModule(name_, version_)
        SubvaultModule(name_, version_)
    {}

    function initialize(bytes calldata initParams) external initializer {
        (address admin_, address verifier_, address rootVault_) = abi.decode(initParams, (address, address, address));
        __VerifierModule_init(admin_, verifier_);
        __SubvaultModule_init(rootVault_);
    }
}
