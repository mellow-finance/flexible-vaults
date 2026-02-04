// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ITeller {
    function deposit(address depositAsset, uint256 depositAmount, uint256 minimumMint, address referralAddress)
        external
        payable
        returns (uint256 shares);
}
