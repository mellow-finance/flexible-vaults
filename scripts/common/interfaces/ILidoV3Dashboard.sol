// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ILidoV3Dashboard {
    function fund() external payable;

    function withdraw(address recipient_, uint256 ether_) external;

    function mintWstETH(address recipient_, uint256 amountOfWstETH_) external payable;

    function burnWstETH(uint256 amountOfWstETH_) external;

    function rebalanceVaultWithShares(uint256 shares_) external;

    function rebalanceVaultWithEther(uint256 ether_) external payable;
}
