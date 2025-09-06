// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/oracles/OracleHelper.sol";
import "../../../src/vaults/Vault.sol";

contract DummyReporter {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    OracleHelper public constant ORACLE_HELPER = OracleHelper(0x000000027f2abf8444E7aB618Fb76CfD30852581);

    function push(Vault vault) external {
        IOracle oracle = vault.oracle();
        uint256 value = IERC20(WSTETH).balanceOf(address(vault))
            + WSTETHInterface(WSTETH).getWstETHByStETH(address(vault).balance + IERC20(WETH).balanceOf(address(vault)));

        uint256 wstethRate = WSTETHInterface(WSTETH).getWstETHByStETH(1 ether);
        uint256[] memory prices;
        if (value == 0) {
            prices = new uint256[](3);
            prices[0] = 1 ether;
            prices[1] = wstethRate;
            prices[2] = wstethRate;
        } else {
            OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](3);

            assetPrices[0].asset = WSTETH;
            assetPrices[1].asset = WETH;
            assetPrices[1].priceD18 = wstethRate;
            assetPrices[2].asset = TransferLibrary.ETH;
            assetPrices[2].priceD18 = wstethRate;
            prices = ORACLE_HELPER.getPricesD18(vault, value, assetPrices);
        }

        IOracle.Report[] memory reports = new IOracle.Report[](3);
        reports[0].asset = WSTETH;
        reports[0].priceD18 = uint224(prices[0]);

        reports[1].asset = WETH;
        reports[1].priceD18 = uint224(prices[1]);

        reports[2].asset = TransferLibrary.ETH;
        reports[2].priceD18 = uint224(prices[2]);

        oracle.submitReports(reports);

        for (uint256 i = 0; i < reports.length; i++) {
            if (oracle.getReport(reports[i].asset).isSuspicious) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(block.timestamp));
            }
        }
    }
}

interface WSTETHInterface {
    function getWstETHByStETH(uint256 amount) external view returns (uint256);
}
