// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Constants} from "../../ethereum/Constants.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract strETHCustomAaveOracle {
    function getAssetPrice(address asset) public view returns (uint256 price) {
        price = strETHCustomAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(asset);
        if (asset == Constants.USDC || asset == Constants.USDT || asset == Constants.USDE) {
            price = Math.min(price, 1e8);
        } else if (asset == Constants.SUSDE) {
            return Math.min(IERC4626(Constants.SUSDE).convertToAssets(1e8), price);
        }
    }
}
