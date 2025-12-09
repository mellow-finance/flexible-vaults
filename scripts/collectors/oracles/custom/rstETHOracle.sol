// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../ICustomPriceOracle.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface _IWSTETH {
    function getStETHByWstETH(uint256) external view returns (uint256);
}

contract rstETHOracle {
    function priceX96() external view returns (uint256) {
        address rsteth = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a;
        address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        return _IWSTETH(wsteth).getStETHByWstETH(IERC4626(rsteth).convertToAssets(2 ** 96));
    }
}
