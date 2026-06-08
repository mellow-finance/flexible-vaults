// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IHook} from "../interfaces/hooks/IHook.sol";
// import {IHookStrategy} from "../interfaces/strategies/IHookStrategy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract TransferDepositHook is IHook {
    // error OnlyDelegateCall();

    // address public immutable asset;
    // address public immutable subvault;
    // address public immutable to;

    // address private _this;

    // constructor(address asset_, address subvault_, address to_) {
    //     asset = asset_;
    //     subvault = subvault_;
    //     to = to_;
    //     _this = address(this);
    // }

    // function callHook(address asset, uint256 assets) public virtual {
    //     if (address(this) == _this) {
    //         revert OnlyDelegateCall();
    //     }

    //     IVaultModule(address(this)).hookPushAssets(
    //         asset,
    //         subvault,
    //         assets
    //     );
        
    // }
}
