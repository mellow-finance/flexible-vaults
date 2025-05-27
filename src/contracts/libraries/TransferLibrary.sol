// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library TransferLibrary {
    using SafeERC20 for IERC20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function transfer(address asset, address from, address to, uint256 assets) internal {
        if (asset == ETH) {
            if (from == address(this)) {
                Address.sendValue(payable(to), assets);
            } else {
                require(msg.value == assets, "TransferLibrary: value mismatch");
                // No need to transfer ETH from 'from' to 'to' as it is already sent with the call
            }
        } else {
            IERC20(asset).safeTransferFrom(from, to, assets);
        }
    }
}
