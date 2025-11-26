// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/libraries/TransferLibrary.sol";

import "../../../src/oracles/OracleHelper.sol";
import "../../../src/vaults/Vault.sol";
import {Constants} from "../../ethereum/Constants.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IWSTETH {
    function getStETHByWstETH(uint256) external view returns (uint256);
}

contract rstETHPlusTestCollector {
    Vault public constant vault = Vault(payable(0x576cf925B2F58328a4Bd5A95A74541a90976e1B4));
    OracleHelper public constant helper = OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35);

    function getPricesD18() external view returns (IOracle.Report[] memory reports) {
        uint256 totalAssets = getTotalAssets(address(vault)) + getTotalAssets(vault.subvaultAt(0));

        OracleHelper.AssetPrice[] memory prices = new OracleHelper.AssetPrice[](4);
        prices[0].asset = Constants.RSTETH;
        prices[0].priceD18 =
            uint224(IWSTETH(Constants.WSTETH).getStETHByWstETH(IERC4626(Constants.RSTETH).convertToAssets(1 ether)));

        prices[1].asset = Constants.WSTETH;
        prices[1].priceD18 = uint224(IWSTETH(Constants.WSTETH).getStETHByWstETH(1 ether));

        prices[2].asset = Constants.WETH;
        prices[2].priceD18 = 1 ether;

        prices[3].asset = Constants.ETH;

        uint256[] memory prices_ = helper.getPricesD18(vault, totalAssets, prices);

        reports = new IOracle.Report[](4);
        for (uint256 i = 0; i < 4; i++) {
            reports[i].asset = prices[3 - i].asset;
            reports[i].priceD18 = uint224(prices_[3 - i]);
        }
    }

    function getTotalAssets(address v) public view returns (uint256) {
        return TransferLibrary.balanceOf(Constants.ETH, v) + TransferLibrary.balanceOf(Constants.WETH, v)
            + IWSTETH(Constants.WSTETH).getStETHByWstETH(
                TransferLibrary.balanceOf(Constants.WSTETH, v)
                    + IERC4626(Constants.RSTETH).convertToAssets(TransferLibrary.balanceOf(Constants.RSTETH, v))
            );
    }
}
