// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/ACLModule.sol";
import "../modules/BaseModule.sol";
import "../modules/DepositModule.sol";
import "../modules/RedeemModule.sol";
import "../modules/ShareModule.sol";
import "../modules/VaultModule.sol";

contract Vault is VaultModule, DepositModule, RedeemModule {
    constructor(
        string memory name_,
        uint256 version_,
        address subvaultFactory_,
        address depositQueueFactory_,
        address redeemQueueFactory_
    )
        ACLModule(name_, version_)
        ShareModule(name_, version_)
        DepositModule(name_, version_, depositQueueFactory_)
        RedeemModule(name_, version_, redeemQueueFactory_)
        VaultModule(name_, version_, subvaultFactory_)
    {}

    function initialize(
        address admin_,
        address shareManager_,
        address feesManager_,
        address riskManager_,
        address depositOracle_,
        address redeemOracle_,
        bytes calldata depositModuleParams_,
        bytes calldata redeemModuleParams_
    ) external initializer {
        __ACLModule_init(admin_);
        __ShareModule_init(shareManager_, feesManager_, depositOracle_, redeemOracle_);
        __VaultModule_init(riskManager_);
        __DepositModule_init(depositModuleParams_);
        __RedeemModule_init(redeemModuleParams_);
    }
}
