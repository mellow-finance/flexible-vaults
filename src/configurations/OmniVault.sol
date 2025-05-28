// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";

import "../modules/DepositModule.sol";
import "../modules/RedeemModule.sol";
import "../modules/SharesModule.sol";

contract OmniVault is PermissionsModule, CallModule, SharesModule, DepositModule, RedeemModule {
    constructor(string memory name_, uint256 version_)
        PermissionsModule(name_, version_)
        CallModule()
        SharesModule(name_, version_)
        DepositModule(name_, version_)
        RedeemModule(name_, version_)
    {
        _disableInitializers();
    }

    function initialize(
        address guard_,
        address admin_,
        address sharesManager_,
        address oracle_,
        uint256 epochDuration_
    ) external initializer {
        __PermissionsModule_init(guard_, admin_);
        __SharesModule_init(sharesManager_, oracle_, epochDuration_);
    }
}
