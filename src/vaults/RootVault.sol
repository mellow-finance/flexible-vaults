// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/ACLModule.sol";
import "../modules/BaseModule.sol";
import "../modules/DepositModule.sol";
import "../modules/RedeemModule.sol";

import "../modules/RootVaultModule.sol";
import "../modules/SharesModule.sol";

contract RootVault is RootVaultModule, DepositModule, RedeemModule {
    constructor(
        string memory name_,
        uint256 version_,
        address subvaultFactory_,
        address depositQueueFactory_,
        address redeemQueueFactory_
    )
        ACLModule(name_, version_)
        SharesModule(name_, version_)
        DepositModule(name_, version_, depositQueueFactory_)
        RedeemModule(name_, version_, redeemQueueFactory_)
        RootVaultModule(name_, version_, subvaultFactory_)
    {}

    function initialize(
        address admin_,
        bytes calldata depositModuleParams_,
        bytes calldata redeemModuleParams_,
        address sharesManager_,
        address depositOracle_,
        address redeemOracle_,
        address riskManager_
    ) external initializer {
        __ACLModule_init(admin_);
        __SharesModule_init(sharesManager_, depositOracle_, redeemOracle_);
        __DepositModule_init(depositModuleParams_);
        __RedeemModule_init(redeemModuleParams_);
        __RootVaultModule_init(riskManager_);
    }
}
