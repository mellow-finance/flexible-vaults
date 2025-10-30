// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {TransferLibrary} from "../libraries/TransferLibrary.sol";
import {IOracle, IShareModule} from "../oracles/Oracle.sol";

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract OracleSubmitter is AccessControlEnumerable {
    error ZeroBaseAsset();
    error InvalidOrder();

    IOracle public immutable oracle;
    address public immutable baseAsset;
    uint8 public immutable decimals;

    int256 public latestAnswer;
    uint32 public updatedAt;
    mapping(address asset => mapping(uint256 index => uint32)) public acceptedAt;

    mapping(address asset => IOracle.DetailedReport[]) private _reports;

    constructor(address admin_, address submitter_, address accepter_, address oracle_) {
        oracle = IOracle(oracle_);
        IShareModule vault = IOracle(oracle).vault();
        baseAsset = vault.feeManager().baseAsset(address(vault));
        if (baseAsset == address(0)) {
            revert ZeroBaseAsset();
        }
        decimals = baseAsset == TransferLibrary.ETH ? 18 : IERC20Metadata(baseAsset).decimals();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(oracle.SUBMIT_REPORTS_ROLE(), submitter_);
        _grantRole(oracle.ACCEPT_REPORT_ROLE(), accepter_);
    }

    // View functions

    function reports(address asset) public view returns (uint256) {
        return _reports[asset].length;
    }

    function reportAt(address asset, uint256 index) public view returns (IOracle.DetailedReport memory) {
        return _reports[asset][index];
    }

    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        uint32 timestamp = updatedAt;
        return (0, latestAnswer, timestamp, timestamp, 0);
    }

    function getRate() public view returns (uint256) {
        return uint256(latestAnswer);
    }

    // Mutable functions

    function submitReports(IOracle.Report[] calldata reports_) external onlyRole(oracle.SUBMIT_REPORTS_ROLE()) {
        if (reports_[0].asset != baseAsset) {
            revert InvalidOrder();
        }
        oracle.submitReports(reports_);
        for (uint256 i = 0; i < reports_.length; i++) {
            address asset = reports_[i].asset;
            IOracle.DetailedReport memory report = oracle.getReport(asset);
            _reports[asset].push(report);
            if (!report.isSuspicious && asset == baseAsset) {
                _updateLatestAnswer(report.priceD18);
            }
        }
    }

    function acceptReports(address[] calldata assets, uint224[] calldata pricesD18, uint32[] calldata timestamps)
        external
        onlyRole(oracle.ACCEPT_REPORT_ROLE())
    {
        uint32 timestamp = uint32(block.timestamp);
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            oracle.acceptReport(asset, pricesD18[i], timestamps[i]);
            if (asset == baseAsset) {
                if (i != 0) {
                    revert InvalidOrder();
                }
                _updateLatestAnswer(pricesD18[i]);
            }
            acceptedAt[asset][reports(asset) - 1] = timestamp;
        }
    }

    // Internal functions

    function _updateLatestAnswer(uint224 priceD18) internal {
        latestAnswer = int256(1e36 / uint256(priceD18));
        updatedAt = uint32(block.timestamp);
    }
}
