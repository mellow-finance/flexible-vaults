// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ISymbioticVault {
    function deposit(address onBehalfOf, uint256 amount)
        external
        returns (uint256 depositedAmount, uint256 mintedShares);

    function withdraw(address claimer, uint256 amount) external returns (uint256 burnedShares, uint256 mintedShares);

    function claim(address recipient, uint256 epoch) external returns (uint256 amount);
}
