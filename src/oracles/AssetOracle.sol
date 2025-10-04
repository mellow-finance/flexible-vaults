// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/external/chainlink/IAggregatorV3.sol";

contract AssetOracle is Ownable {
    error LimitOverflow();
    error BothNonZero();

    address public immutable fallbackOracle;
    mapping(address asset => bytes32) private _data;

    constructor(address owner_, address fallbackOracle_) Ownable(owner_) {
        fallbackOracle = fallbackOracle_;
    }

    // View functions

    /// @dev Returns oracle configuration for a given asset.
    /// @param asset Address of the asset.
    /// @return assetOracle External oracle contract (Chainlink-like with latestAnswer(), 8 decimals).
    /// @return constantValue Fixed price in 8-decimals format.
    function getAssetInfo(address asset) public view returns (address assetOracle, uint256 constantValue) {
        bytes32 data = _data[asset];
        assetOracle = address(bytes20(data));
        constantValue = uint96(uint256(data));
    }

    function getAssetPrice(address asset) public view returns (uint256) {
        (address assetOracle, uint256 constantValue) = getAssetInfo(asset);
        if (constantValue != 0) {
            return constantValue;
        }
        if (assetOracle != address(0)) {
            int256 price = IAggregatorV3(assetOracle).latestAnswer();
            if (price > 0) {
                return uint256(price);
            }
        }
        return AssetOracle(fallbackOracle).getAssetPrice(asset);
    }

    function getValueOf(address asset, uint256 amount) public view returns (uint256) {
        return Math.mulDiv(getAssetPrice(asset), amount, 10 ** IERC20Metadata(asset).decimals());
    }

    // Mutable functions

    function setAssetInfo(address asset, address oracle, uint256 constantValue) external onlyOwner {
        if (constantValue > type(uint96).max) {
            revert LimitOverflow();
        }
        if (constantValue > 0 && oracle != address(0)) {
            revert BothNonZero();
        }

        _data[asset] = bytes32((uint256(uint160(oracle)) << 96) | constantValue);
        emit SetAssetInfo(asset, oracle, constantValue);
    }

    event SetAssetInfo(address indexed asset, address indexed oracle, uint256 constantValue);
}
