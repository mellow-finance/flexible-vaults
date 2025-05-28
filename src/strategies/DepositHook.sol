// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

abstract contract DepositHook {
    address private immutable this_;

    constructor() {
        this_ = address(this);
    }

    modifier onlyDelegateCall() {
        require(address(this) != this_, "DepositHook: must be called via delegatecall");
        _;
    }

    function hook(address asset, uint256 assets) external virtual returns (address, uint256);
}
