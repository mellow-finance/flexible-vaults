// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./ICustomPriceOracle.sol";
import "./IPriceOracle.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PriceOracle is IPriceOracle, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant Q96 = 2 ** 96;

    struct TokenOracle {
        uint256 constValue;
        address oracle;
    }

    mapping(address token => TokenOracle) public oracles;
    EnumerableSet.AddressSet private _assets;

    constructor(address owner_) Ownable(owner_) {}

    function assets() public view returns (address[] memory) {
        return _assets.values();
    }

    function setOracle(address token, address oracle, uint256 constValue) external onlyOwner {
        oracles[token] = TokenOracle(constValue, oracle);
        if (constValue > 0 || oracle != address(0)) {
            _assets.add(token);
        } else {
            _assets.remove(token);
        }
    }

    function setOracles(address[] calldata tokens_, TokenOracle[] calldata oracles_) external onlyOwner {
        require(tokens_.length == oracles_.length, "PriceOracle: invalid input");
        for (uint256 i = 0; i < tokens_.length; i++) {
            oracles[tokens_[i]] = oracles_[i];
            if (oracles_[i].constValue > 0 || oracles_[i].oracle != address(0)) {
                _assets.add(tokens_[i]);
            } else {
                _assets.remove(tokens_[i]);
            }
        }
    }

    /// @dev returns price in Q96 math in ETH for `token`
    function priceX96(address token) public view returns (uint256) {
        TokenOracle memory oracle = oracles[token];
        if (oracle.constValue != 0) {
            return oracle.constValue;
        }
        if (oracle.oracle == address(0)) {
            revert("PriceOracle: no oracle");
        }
        return ICustomPriceOracle(oracle.oracle).priceX96();
    }

    /// @dev returns price in Q96 math in `priceToken` for `token`
    function priceX96(address token, address priceToken) public view returns (uint256) {
        return Math.mulDiv(priceX96(token), Q96, priceX96(priceToken));
    }

    function getValue(address token, uint256 amount) public view returns (uint256) {
        if (amount > type(uint128).max) {
            return type(uint256).max;
        }
        return Math.mulDiv(priceX96(token), amount, Q96);
    }

    function getValue(address token, address priceToken, uint256 amount) public view returns (uint256) {
        if (amount > type(uint128).max) {
            return type(uint256).max;
        }
        return Math.mulDiv(priceX96(token, priceToken), amount, Q96);
    }
}
