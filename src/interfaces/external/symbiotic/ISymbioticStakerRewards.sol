// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISymbioticStakerRewards {
    function version() external view returns (uint64);

    function claimable(address token, address account, bytes calldata data) external view returns (uint256);

    function distributeRewards(address network, address token, uint256 amount, bytes calldata data) external;

    function claimRewards(address recipient, address token, bytes calldata data) external;
}
