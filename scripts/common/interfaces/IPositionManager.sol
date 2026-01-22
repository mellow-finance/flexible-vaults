// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAllowanceTransfer {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IPositionManager is IERC721 {
    /// @notice Unlocks Uniswap v4 PoolManager and batches actions for modifying liquidity
    /// @dev This is the standard entrypoint for the PositionManager
    /// @param unlockData is an encoding of actions, and parameters for those actions
    /// @param deadline is the deadline for the batched actions to be executed
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external;

    function poolManager() external view returns (address);

    function permit2() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function nextTokenId() external view returns (uint256);
}
