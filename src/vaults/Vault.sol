// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/factories/IFactoryEntity.sol";

import "../modules/ACLModule.sol";
import "../modules/ShareModule.sol";
import "../modules/VaultModule.sol";

contract Vault is IFactoryEntity, VaultModule, ShareModule {
    struct RoleHolder {
        bool isFundamental;
        bytes32 role;
        address holder;
    }

    constructor(
        string memory name_,
        uint256 version_,
        address depositQueueFactory_,
        address redeemQueueFactory_,
        address subvaultFactory_,
        address verifierFactory_
    )
        ACLModule(name_, version_)
        ShareModule(name_, version_, depositQueueFactory_, redeemQueueFactory_)
        VaultModule(name_, version_, subvaultFactory_, verifierFactory_)
    {}

    function initialize(bytes calldata initParams) external initializer {
        (
            address admin_,
            address shareManager_,
            address feeManager_,
            address riskManager_,
            address oracle_,
            address defaultDepositHook_,
            address defaultRedeemHook_,
            RoleHolder[] memory roleHolders
        ) = abi.decode(initParams, (address, address, address, address, address, address, address, RoleHolder[]));
        __ACLModule_init(admin_);
        __ShareModule_init(shareManager_, feeManager_, oracle_, defaultDepositHook_, defaultRedeemHook_);
        __VaultModule_init(riskManager_);
        RoleHolder memory roleHolder;
        for (uint256 i = 0; i < roleHolders.length; i++) {
            roleHolder = roleHolders[i];
            if (roleHolder.isFundamental) {
                _grantFundamentalRole(FundamentalRole(uint256(roleHolder.role)), roleHolder.holder);
            } else {
                _grantRole(roleHolder.role, roleHolder.holder);
            }
        }
    }
}
