// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/hooks/IDepositHook.sol";

contract CompositeDepositHook is IDepositHook {
    address public immutable hook0;
    address public immutable hook1;
    address public immutable hook2;
    address public immutable hook3;

    constructor(address hook0_, address hook1_, address hook2_, address hook3_) {
        hook0 = hook0_;
        hook1 = hook1_;
        hook2 = hook2_;
        hook3 = hook3_;
    }

    function afterDeposit(address vault, address asset, uint256 assets) public virtual {
        bytes memory data = abi.encodeCall(IDepositHook.afterDeposit, (vault, asset, assets));
        Address.functionDelegateCall(hook0, data);
        if (hook1 == address(0)) {
            return;
        }
        Address.functionDelegateCall(hook1, data);
        if (hook2 == address(0)) {
            return;
        }
        Address.functionDelegateCall(hook2, data);
        if (hook3 == address(0)) {
            return;
        }
        Address.functionDelegateCall(hook3, data);
    }
}
