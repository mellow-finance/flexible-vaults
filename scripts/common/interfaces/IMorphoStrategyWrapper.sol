// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IMorphoStrategyWrapper {
    function REWARD_VAULT() external view returns (address);
    function LENDING_PROTOCOL() external view returns (address);
    function lendingMarketId() external view returns (bytes32);

    // Deposit
    function depositAssets(uint256 amount) external;

    // Withdraw
    function withdraw(uint256 amount) external;

    // Claim main reward token (e.g. CRV)
    function claim() external returns (uint256 amount);
    function claimExtraRewards() external returns (uint256[] memory amounts);
}
