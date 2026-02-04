// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAllowanceTransfer {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IPoolManager {
    function extsload(bytes32 slot) external view returns (bytes32 value);
}

interface IPositionManagerV4 is IERC721 {
    /// @notice Returns the key for identifying a pool
    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        address currency0;
        /// @notice The higher currency of the pool, sorted numerically
        address currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        address hooks;
    }

    /// @notice Unlocks Uniswap v4 PoolManager and batches actions for modifying liquidity
    /// @dev This is the standard entrypoint for the PositionManager
    /// @param unlockData is an encoding of actions, and parameters for those actions
    /// @param deadline is the deadline for the batched actions to be executed
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external;

    function poolManager() external view returns (address);

    function permit2() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function nextTokenId() external view returns (uint256);

    function poolKeys(bytes25 poolId) external view returns (PoolKey memory);

    function getApproved(uint256 tokenId) external view returns (address);

    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory poolKey, uint256 info);
}
