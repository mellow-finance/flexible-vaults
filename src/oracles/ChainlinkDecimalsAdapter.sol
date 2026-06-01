// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IChainlinkSource {
    function latestAnswer() external view returns (int256);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice Rescales a Chainlink-style feed's answer to a different decimals.
/// @dev Pass-through for everything else. Source must report a positive answer.
contract ChainlinkDecimalsAdapter {
    error InvalidDecimals();

    IChainlinkSource public immutable source;
    uint8 public immutable sourceDecimals;
    uint8 public immutable decimals;
    string public description;

    constructor(address source_, uint8 sourceDecimals_, uint8 decimals_, string memory description_) {
        if (sourceDecimals_ > 36 || decimals_ > 36) {
            revert InvalidDecimals();
        }
        source = IChainlinkSource(source_);
        sourceDecimals = sourceDecimals_;
        decimals = decimals_;
        description = description_;
    }

    function latestAnswer() external view returns (int256) {
        return _rescale(source.latestAnswer());
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = source.latestRoundData();
        answer = _rescale(answer);
    }

    function _rescale(int256 raw) internal view returns (int256) {
        if (sourceDecimals == decimals) {
            return raw;
        }
        if (sourceDecimals > decimals) {
            return raw / int256(10 ** uint256(sourceDecimals - decimals));
        }
        return raw * int256(10 ** uint256(decimals - sourceDecimals));
    }
}
