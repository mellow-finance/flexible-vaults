// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title TransferLibrary
/// @notice Library for unified handling of native ETH and ERC20 asset transfers.
/// @dev Provides safe and abstracted methods for sending and receiving both ETH and ERC20 tokens.
///
/// # ETH Convention
/// Uses the constant `ETH = 0xEeee...EeE` to distinguish native ETH from ERC20 tokens.
library TransferLibrary {
    using SafeERC20 for IERC20;

    /// @notice Error thrown when `msg.value` does not match expected ETH amount
    error InvalidValue();

    /// @dev Placeholder address used to represent native ETH transfers
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Safely sends assets (ETH or ERC20) to a recipient
    /// @param asset Address of the asset to send (use `ETH` constant for native ETH)
    /// @param to Recipient address
    /// @param assets Amount of assets to send
    /// @dev Uses `Address.sendValue` for ETH and `safeTransfer` for ERC20
    function sendAssets(address asset, address to, uint256 assets) internal {
        if (asset == ETH) {
            Address.sendValue(payable(to), assets);
        } else {
            IERC20(asset).safeTransfer(to, assets);
        }
    }

    /// @notice Safely receives assets (ETH or ERC20) from a sender
    /// @param asset Address of the asset to receive (use `ETH` constant for native ETH)
    /// @param from Sender address (only used for ERC20)
    /// @param assets Amount of assets expected to receive
    /// @dev Reverts if `msg.value` is incorrect for ETH or uses `safeTransferFrom` for ERC20
    function receiveAssets(address asset, address from, uint256 assets) internal {
        if (asset == ETH) {
            if (msg.value != assets) {
                revert InvalidValue();
            }
        } else {
            IERC20(asset).safeTransferFrom(from, address(this), assets);
        }
    }
}
