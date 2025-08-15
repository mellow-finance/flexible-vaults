// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/oracles/OracleHelper.sol";

contract MockOracleHelper is OracleHelper {
    function find(
        address feeManager,
        address vault,
        uint256 left,
        uint256 right,
        address baseAsset,
        uint256 totalShares,
        uint256 recipientShares,
        uint256 assets
    ) external view returns (uint256 basePriceD18) {
        return _find(
            IFeeManager(feeManager), Vault(payable(vault)), left, right, baseAsset, totalShares, recipientShares, assets
        );
    }
}

contract MockFeeManager {
    uint256 private _minPriceD18;
    uint24 private _performanceFeeD6;
    uint24 private _protocolFeeD6;
    uint256 private _timestamp;

    function setMinPrice(uint256 minPriceD18_) public {
        _minPriceD18 = minPriceD18_;
    }

    function setTimestamp(uint256 timestamp_) public {
        _timestamp = timestamp_;
    }

    function setPerformanceFee(uint24 performanceFeeD6_) public {
        _performanceFeeD6 = performanceFeeD6_;
    }

    function setProtocolFee(uint24 protocolFeeD6_) public {
        _protocolFeeD6 = protocolFeeD6_;
    }

    function minPriceD18() public view returns (uint256) {
        return _minPriceD18;
    }

    function performanceFeeD6() public view returns (uint24) {
        return _performanceFeeD6;
    }

    function protocolFeeD6() public view returns (uint24) {
        return _protocolFeeD6;
    }

    function timestamp() public view returns (uint256) {
        return _timestamp;
    }

    function calculateFee(address, address, uint256 priceD18, uint256 totalShares)
        public
        view
        returns (uint256 shares)
    {
        uint256 minPriceD18_ = _minPriceD18;
        if (priceD18 < minPriceD18_ && minPriceD18_ != 0) {
            shares = Math.mulDiv(minPriceD18_ - priceD18, _performanceFeeD6 * totalShares, priceD18 * 1e6);
        }
        uint256 timestamp_ = _timestamp;
        if (timestamp_ != 0 && block.timestamp > timestamp_) {
            shares += Math.mulDiv(totalShares, _protocolFeeD6 * (block.timestamp - timestamp_), 365e6 days);
        }
    }
}
