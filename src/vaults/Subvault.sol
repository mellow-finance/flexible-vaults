// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/factories/IFactoryEntity.sol";
import "../modules/CallModule.sol";
import "../modules/SubvaultModule.sol";

contract Subvault is IFactoryEntity, CallModule, SubvaultModule {
    constructor(string memory name_, uint256 version_)
        VerifierModule(name_, version_)
        SubvaultModule(name_, version_)
    {}

    function initialize(bytes calldata initParams) external initializer {
        (address verifier_, address vault_) = abi.decode(initParams, (address, address));
        __VerifierModule_init(verifier_);
        __SubvaultModule_init(vault_);
        emit Initialized(initParams);
    }
}
