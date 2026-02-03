// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IEthWrapper {
    function deposit(address depositToken, uint256 amount, address vault, address receiver, address referral)
        external
        payable
        returns (uint256 shares);
}
