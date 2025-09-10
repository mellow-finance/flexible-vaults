// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/oracles/OracleHelper.sol";
import "../../../src/vaults/Vault.sol";

contract DummyReporterTheoriq {
    OracleHelper public constant ORACLE_HELPER = OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35);

    function push(Vault vault) external {
        IOracle oracle = vault.oracle();
        uint256 value = address(vault).balance;

        IOracle.Report[] memory reports = new IOracle.Report[](1);
        reports[0].asset = TransferLibrary.ETH;
        if (value == 0) {
            reports[0].priceD18 = uint224(1 ether);
        } else {
            OracleHelper.AssetPrice[] memory assetPrices = new OracleHelper.AssetPrice[](1);
            assetPrices[0].asset = TransferLibrary.ETH;
            reports[0].priceD18 = uint224(ORACLE_HELPER.getPricesD18(vault, address(vault).balance, assetPrices)[0]);
        }

        oracle.submitReports(reports);

        for (uint256 i = 0; i < reports.length; i++) {
            if (oracle.getReport(reports[i].asset).isSuspicious) {
                oracle.acceptReport(reports[i].asset, reports[i].priceD18, uint32(block.timestamp));
            }
        }
    }
}
