// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/oracles/IOracle.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IWSTETH {
    function getStETHByWstETH(uint256 amount) external view returns (uint256);
}

contract ChainlinkOraclePriceFeed {
    error ZeroPrice();
    error SuspiciousReport();

    address public immutable oracle;
    address public immutable baseAsset;
    bool public immutable wstethToEth;
    bool public immutable revertOnSuspicious;

    uint8 public constant decimals = 18;

    constructor(address oracle_, address baseAsset_, bool wstethToEth_, bool revertOnSuspicious_) {
        oracle = oracle_;
        baseAsset = baseAsset_;
        wstethToEth = wstethToEth_;
        revertOnSuspicious = revertOnSuspicious_;
    }

    function latestRoundData()
        public
        view
        returns (uint80, int256 answer, uint256 startedAt, uint256 updatedAt, uint80)
    {
        IOracle.DetailedReport memory report = IOracle(oracle).getReport(baseAsset);
        if (report.priceD18 == 0) {
            revert ZeroPrice();
        }

        if (revertOnSuspicious && report.isSuspicious) {
            revert SuspiciousReport();
        }

        startedAt = report.timestamp;
        updatedAt = updatedAt;

        uint256 priceD18 = 1e36 / report.priceD18;
        if (wstethToEth) {
            priceD18 = IWSTETH(baseAsset).getStETHByWstETH(priceD18);
        }
        answer = int256(priceD18);
    }

    function latestAnswer() public view returns (int256 answer) {
        (, answer,,,) = latestRoundData();
    }

    function getRate() public view returns (uint256) {
        return uint256(latestAnswer());
    }
}
