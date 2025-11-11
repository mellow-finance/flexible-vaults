// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.25;

interface IStakeWiseEthVault {
    function deposit(address receiver, address referrer) external payable returns (uint256 shares);

    function depositAndMintOsToken(address receiver, uint256 osTokenShares, address referrer)
        external
        payable
        returns (uint256);

    function mintOsToken(address receiver, uint256 osTokenShares, address referrer) external returns (uint256 assets);

    function burnOsToken(uint128 osTokenShares) external returns (uint256 assets);

    function enterExitQueue(uint256 shares, address receiver) external returns (uint256 positionTicket);

    function claimExitedAssets(uint256 positionTicket, uint256 timestamp, uint256 exitQueueIndex) external;
}
