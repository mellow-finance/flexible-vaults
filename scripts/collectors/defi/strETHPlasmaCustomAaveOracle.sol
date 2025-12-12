// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Constants} from "../../plasma/Constants.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IFluidGenericOracle {
    function getExchangeRate() external view returns (uint256);
    function targetDecimals() external view returns (uint8);
}

contract strETHPlasmaCustomAaveOracle {
    function getAssetPrice(address asset) public view returns (uint256 price) {
        if (asset == Constants.WSTUSR) {
            return 112277013;
            // price = getAssetPrice(Constants.USDT0);
            // return Math.mulDiv(
            //     IFluidGenericOracle(Constants.FLUID_WSTUSR_USDT0_EXCHANGE_ORACLE).getExchangeRate(),
            //     price,
            //     10 ** IFluidGenericOracle(Constants.FLUID_WSTUSR_USDT0_EXCHANGE_ORACLE).targetDecimals()
            // );
        }
        price = strETHPlasmaCustomAaveOracle(Constants.AAVE_V3_ORACLE).getAssetPrice(asset);
        if (asset == Constants.USDT0) {
            price = Math.min(price, 1e8);
        }
    }
}
