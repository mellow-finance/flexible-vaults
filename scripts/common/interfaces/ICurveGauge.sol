// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICurveGauge is IERC20Metadata {
    function deposit(uint256 _value) external;

    function withdraw(uint256 _value) external;

    function claim_rewards() external;
}
