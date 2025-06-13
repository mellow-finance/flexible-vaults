// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";
import "../modules/VerifierModule.sol";

contract Subvault is CallModule {
    constructor(string memory name_, uint256 version_) VerifierModule(name_, version_) {}

    function initialize(bytes calldata initParams) external initializer {
        (address admin_, address verifier_) = abi.decode(initParams, (address, address));
        __VerifierModule_init(admin_, verifier_);
    }
}
