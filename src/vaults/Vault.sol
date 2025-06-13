// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/ACLModule.sol";
import "../modules/BaseModule.sol";
import "../modules/DepositModule.sol";
import "../modules/RedeemModule.sol";
import "../modules/SharesModule.sol";
import "../modules/SubvaultModule.sol";

contract Vault is ACLModule, SubvaultModule, DepositModule, RedeemModule {
    constructor(
        string memory name_,
        uint256 version_,
        address depositQueueFactory_,
        address redeemQueueFactory_,
        address subvaultFactory_
    )
        ACLModule(name_, version_)
        SharesModule(name_, version_)
        SubvaultModule(name_, version_, subvaultFactory_)
        DepositModule(name_, version_, depositQueueFactory_)
        RedeemModule(name_, version_, redeemQueueFactory_)
    {}

    function initialize(address admin_, address sharesManager_, address oracle_, uint256 epochDuration_)
        external
        initializer
    {
        // __ACLModule_init(admin_);
        // __DepositModule_init();
        // __RedeemModule_init();
        // __SharesModule_init(sharesManager_, oracle_, epochDuration_);
    }
}
