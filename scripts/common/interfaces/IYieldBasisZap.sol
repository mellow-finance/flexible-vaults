// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IYieldBasisZap {
    function deposit_and_stake(address gauge, uint256 assets, uint256 debt, uint256 min_shares)
        external
        returns (uint256);

    function withdraw_and_unstake(address gauge, uint256 shares, uint256 min_assets) external returns (uint256);
}
