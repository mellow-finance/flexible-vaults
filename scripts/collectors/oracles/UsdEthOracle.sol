// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IAggregatorV3.sol";
import "./ICustomPriceOracle.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract UsdEthOracle is ICustomPriceOracle {
    // base
    address public constant aggregatorV3 = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;

    function priceX96() external view returns (uint256) {
        uint256 priceD8 = uint256(IAggregatorV3(aggregatorV3).latestAnswer());
        return Math.mulDiv(1 ether, 2 ** 96, priceD8);
    }
}
