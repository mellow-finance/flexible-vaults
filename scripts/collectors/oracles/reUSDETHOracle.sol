// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IInsuranceCapitalLayer} from "../../common/interfaces/IReUSD.sol";
import "./IAggregatorV3.sol";
import "./ICustomPriceOracle.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "src/interfaces/external/aave/IAaveOracle.sol";

contract reUSDETHOracle is ICustomPriceOracle {
    address public constant AAVE_V3_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;
    address public constant REUSD_ICL = 0x4691C475bE804Fa85f91c2D6D0aDf03114de3093;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant aggregatorV3 = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;

    /// @dev returns price in Q96 math in ETH
    function priceX96() external view returns (uint256) {
        uint256 udscPriceD8 = IAaveOracle(AAVE_V3_ORACLE).getAssetPrice(USDC);
        /// shares per 1 USDC deposited
        (uint256 sharesD18,,,) = IInsuranceCapitalLayer(REUSD_ICL).previewDeposit(USDC, 1e6);
        // USDC price in ETH
        uint256 priceD18 = uint256(IAggregatorV3(aggregatorV3).latestAnswer());
        // 1 ether / sharesD18 = REUSD price in USDC
        return Math.mulDiv(priceD18 * udscPriceD8, 2 ** 96, sharesD18 * 1e8);
    }
}
