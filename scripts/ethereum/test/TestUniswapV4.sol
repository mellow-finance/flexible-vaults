// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Script} from "forge-std/Script.sol";
import {IAllowanceTransfer, IPositionManager} from "scripts/common/interfaces/IPositionManager.sol";

contract Mock {
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

    using SafeERC20 for IERC20;

    function mint() external {
        uint256 tokenId = IPositionManager(Constants.UNISWAP_V4_POSITION_MANAGER).nextTokenId();
        address permit2 = IPositionManager(Constants.UNISWAP_V4_POSITION_MANAGER).permit2();
        address sender = msg.sender;
        address this_ = address(this);
        IERC20(Constants.USDC).safeIncreaseAllowance(permit2, IERC20(Constants.USDC).balanceOf(this_));
        IERC20(Constants.USDT).safeIncreaseAllowance(permit2, IERC20(Constants.USDT).balanceOf(this_));
        IAllowanceTransfer(permit2).approve(
            Constants.USDC, Constants.UNISWAP_V4_POSITION_MANAGER, type(uint160).max, uint48(block.timestamp + 365 days)
        );
        IAllowanceTransfer(permit2).approve(
            Constants.USDT, Constants.UNISWAP_V4_POSITION_MANAGER, type(uint160).max, uint48(block.timestamp + 365 days)
        );
        PoolKey memory poolKey =
            PoolKey({currency0: Constants.USDC, currency1: Constants.USDT, fee: 10, tickSpacing: 1, hooks: address(0)});

        bytes memory actions = abi.encodePacked(uint8(0x02), uint8(0x0d));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, -10, 10, 1e6, 1e6, 1e6, msg.sender, "");
        params[1] = abi.encode(Constants.USDC, Constants.USDT); // SETTLE_PAIR
        IPositionManager(Constants.UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params), block.timestamp + 1 hours
        );

        IPositionManager(Constants.UNISWAP_V4_POSITION_MANAGER).balanceOf(msg.sender);
        require(IPositionManager(Constants.UNISWAP_V4_POSITION_MANAGER).ownerOf(tokenId) == sender, "Not owner");
    }
}

contract TestUniswapV4 is Script {
    using SafeERC20 for IERC20;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address user = vm.addr(deployerPk);
        vm.startPrank(user);
        Mock mock = new Mock();
        IERC20(Constants.USDC).safeTransfer(address(mock), 1e6);
        IERC20(Constants.USDT).safeTransfer(address(mock), 1e6);
        mock.mint();
        vm.stopPrank();
        revert("ok");
    }
}
