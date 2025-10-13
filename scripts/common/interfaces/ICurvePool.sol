// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICurvePool is IERC20Metadata {
    function N_COINS() external view returns (uint256);

    function coins(uint256) external view returns (address);

    function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

    function remove_liquidity(uint256 _burn_amount, uint256[] memory _min_amounts)
        external
        returns (uint256[] memory);
}
