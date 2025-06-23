// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/ACLModule.sol";
import "../modules/ShareModule.sol";
import "../modules/VaultModule.sol";

contract Vault is VaultModule, ShareModule {
    constructor(
        string memory name_,
        uint256 version_,
        address depositQueueFactory_,
        address redeemQueueFactory_,
        address subvaultFactory_
    )
        ACLModule(name_, version_)
        ShareModule(name_, version_, depositQueueFactory_, redeemQueueFactory_)
        VaultModule(name_, version_, subvaultFactory_)
    {}

    function initialize(
        address admin_,
        address shareManager_,
        address feeManager_,
        address riskManager_,
        address depositOracle_,
        address redeemOracle_,
        address defaultDepositHook_,
        address defaultRedeemHook_
    ) external initializer {
        __ACLModule_init(admin_);
        __ShareModule_init(
            shareManager_, feeManager_, depositOracle_, redeemOracle_, defaultDepositHook_, defaultRedeemHook_
        );
        __VaultModule_init(riskManager_);
    }
}
