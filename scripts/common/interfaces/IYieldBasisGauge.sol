// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IYieldBasisGauge is IERC4626 {
    function claim(address reward) external returns (uint256);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);
}
