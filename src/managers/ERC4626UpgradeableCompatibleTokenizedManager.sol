// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IOracle} from "../interfaces/oracles/IOracle.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "./TokenizedShareManager.sol";

contract ERC4626UpgradeableCompatibleTokenizedManager is TokenizedShareManager {
    error InvalidReport();

    constructor(string memory name_, uint256 version_) TokenizedShareManager(name_, version_) {}

    // View functions

    function asset() public view returns (address) {
        ERC4626Upgradeable.ERC4626Storage storage $;
        assembly {
            $.slot := 0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00
        }
        return address($._asset);
    }

    function totalAssets() public view returns (uint256) {
        IOracle.DetailedReport memory report = IShareModule(vault()).oracle().getReport(asset());
        if (report.priceD18 == 0 || report.isSuspicious) {
            revert InvalidReport();
        }
        return Math.mulDiv(totalSupply(), 1 ether, report.priceD18);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return Math.mulDiv(shares, totalAssets() + 1, totalSupply() + 1);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return Math.mulDiv(assets, totalSupply() + 1, totalAssets() + 1);
    }
}
