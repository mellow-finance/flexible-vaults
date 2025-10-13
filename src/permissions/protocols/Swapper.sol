// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../libraries/TransferLibrary.sol";
import "./OwnedCustomVerifier.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Swapper is OwnedCustomVerifier, ReentrancyGuardUpgradeable {
    error LimitUnderflow();
    error Deadline();

    using SafeERC20 for IERC20;

    struct ExchangeParams {
        address router;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
    }

    bytes32 public constant VAULT_ROLE = keccak256("permissions.protocols.ERC20Swapper.VAULT_ROLE");
    bytes32 public constant ASSET_ROLE = keccak256("permissions.protocols.ERC20Swapper.ASSET_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("permissions.protocols.ERC20Swapper.ROUTER_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.ERC20Swapper.CALLER_ROLE");

    constructor(string memory name_, uint256 version_) OwnedCustomVerifier(name_, version_) {}

    function exchange(ExchangeParams calldata params, bytes calldata payload)
        external
        payable
        nonReentrant
        onlyRole(VAULT_ROLE)
        returns (bytes memory response)
    {
        if (params.deadline < block.timestamp) {
            revert Deadline();
        }
        address caller = _msgSender();
        uint256 balanceInBefore = TransferLibrary.balanceOf(params.tokenIn, address(this));
        uint256 balanceOutBefore = TransferLibrary.balanceOf(params.tokenOut, address(this));

        TransferLibrary.receiveAssets(params.tokenIn, caller, params.amountIn);

        if (params.tokenIn == TransferLibrary.ETH) {
            response = Address.functionCallWithValue(params.router, payload, params.amountIn);
        } else {
            IERC20(params.tokenIn).safeIncreaseAllowance(params.router, params.amountIn);
            response = Address.functionCallWithValue(params.router, payload, 0);
            IERC20(params.tokenIn).forceApprove(params.router, 0);
        }

        uint256 amountIn = balanceInBefore - TransferLibrary.balanceOf(params.tokenIn, address(this));
        uint256 amountOut = TransferLibrary.balanceOf(params.tokenOut, address(this)) - balanceOutBefore;

        if (amountOut < params.minAmountOut) {
            revert LimitUnderflow();
        }

        TransferLibrary.sendAssets(params.tokenOut, caller, amountOut);

        uint256 leftover = params.amountIn - amountIn;
        if (leftover > 0) {
            TransferLibrary.sendAssets(params.tokenOut, caller, leftover);
        }
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (!hasRole(CALLER_ROLE, who) || where != address(this) || callData.length < 4) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        if (selector != Swapper.exchange.selector) {
            return false;
        }
        ExchangeParams memory params = abi.decode(callData[4:], (ExchangeParams));
        if (params.tokenIn == TransferLibrary.ETH) {
            if (value == 0 || value != params.amountIn) {
                return false;
            }
        } else {
            if (value > 0 || params.amountIn == 0) {
                return false;
            }
        }

        if (params.tokenIn == params.tokenOut) {
            return false;
        }
        if (
            !hasRole(ASSET_ROLE, params.tokenIn) || !hasRole(ASSET_ROLE, params.tokenOut)
                || !hasRole(ROUTER_ROLE, params.router)
        ) {
            return false;
        }
        if (params.minAmountOut == 0) {
            return false;
        }
        if (params.deadline < block.timestamp) {
            return false;
        }

        return true;
    }
}
