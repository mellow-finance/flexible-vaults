// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library TransferLibrary {
    using SafeERC20 for IERC20;

    error InvalidValue();

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function sendAssets(address asset, address to, uint256 assets) internal {
        if (asset == ETH) {
            Address.sendValue(payable(to), assets);
        } else {
            IERC20(asset).safeTransfer(to, assets);
        }
    }

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
