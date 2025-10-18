// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/oracles/IOracle.sol";

contract ChainlinkOraclePriceFeed {
    error ZeroPrice();
    error SuspiciousReport();

    address public immutable oracle;
    address public immutable baseAsset;
    address public immutable wstethToEth;
    address public immutable revertOnSuspicious;

    uint8 public constant decimals = 18;
    uint256 public constant latestRound = 0;

    constructor(address oracle_, address baseAsset_, bool wstethToEth_, bool revertOnSuspicious_) {
        oracle = oracle_;
        baseAsset = baseAsset_;
        wstethToEth = wstethToEth_;
        revertOnSuspicious = revertOnSuspicious_;
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        IOracle.DetailedReport memory report = IOracle(oracle).getReport(baseAsset);
        if (report.priceD18 == 0) {
            revert ZeroPrice();
        }

        if (revertOnSuspicious && report.isSuspicious) {
            revert SuspiciousReport();
        }

        roundId = 0;
        answeredInRound = 0;
        answer = 1e36 / report.priceD18;
        updatedAt = report.timestamp;
    }

    function latestAnswer() external view returns (int256 answer) {
        (, answer,,,) = latestRoundData();
    }

    function latestTimestamp() external view returns (uint256 timestamp) {
        (,,, timestamp,) = latestRoundData();
    }

    function getRate() public view returns (uint256) {
        return uint256(latestAnswer());
    }
}
