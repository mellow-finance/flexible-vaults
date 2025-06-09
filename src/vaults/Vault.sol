// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/ACLPermissionsModule.sol";
import "../modules/BaseModule.sol";
import "../modules/DepositModule.sol";
import "../modules/RedeemModule.sol";
import "../modules/SharesModule.sol";
import "../modules/SubvaultFactoryModule.sol";

contract Vault is ACLPermissionsModule, SubvaultFactoryModule, DepositModule, RedeemModule, SharesModule {
    constructor(string memory name_, uint256 version_)
        SubvaultFactoryModule(name_, version_)
        SharesModule(name_, version_)
        DepositModule(name_, version_)
        RedeemModule(name_, version_)
    {}

    function initialize(address admin_, address sharesManager_, address oracle_, uint256 epochDuration_)
        external
        initializer
    {
        __ACLPermissionsModule_init(admin_);
        // __DepositModule_init();
        // __RedeemModule_init();
        __SharesModule_init(sharesManager_, oracle_, epochDuration_);
    }
}
