// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/interfaces/oracles/IOracle.sol";
import "../../../src/vaults/Vault.sol";

import "../../common/Permissions.sol";
import "forge-std/Script.sol";

abstract contract AuroBTC_AcceptReportBase is Script {
    // wBTC address on Ethereum mainnet
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOT_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("Vault address:", vaultAddress);
        console2.log("Deployer:", deployer);

        Vault vault = Vault(payable(vaultAddress));
        IOracle oracle = vault.oracle();

        IOracle.DetailedReport memory report = oracle.getReport(WBTC);

        console2.log("Report priceD18:", report.priceD18);
        console2.log("Report timestamp:", report.timestamp);
        console2.log("Report isSuspicious:", report.isSuspicious);

        require(report.priceD18 > 0, "Report not found");
        require(report.isSuspicious, "Report is not suspicious - already accepted");

        vm.startBroadcast(deployerPk);

        // Accept the report using the actual on-chain timestamp. For some
        // reason, if this step is executed along the deployment, foundry embeds
        // the simulated timestamp (my guess) in the transaction instead of
        // properly querying it, resulting in an invalid report.
        oracle.acceptReport(WBTC, report.priceD18, report.timestamp);
        vault.renounceRole(Permissions.ACCEPT_REPORT_ROLE, deployer);

        vm.stopBroadcast();
    }
}
