// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IBracketVaultV2 is IERC20Metadata {
    function token() external view returns (address);

    function deposit(uint256 assets, address destination) external;

    function withdraw(uint256 assets, bytes32 salt) external;

    function claimWithdrawal(uint256 shares, uint16 claimEpoch, uint256 timestamp, bytes32 salt) external;
}
