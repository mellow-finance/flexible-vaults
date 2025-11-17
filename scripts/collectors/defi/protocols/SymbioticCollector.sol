// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

interface ISymbioticVault {
    function currentEpoch() external view returns (uint256);

    function collateral() external view returns (address);

    function activeBalanceOf(address account) external view returns (uint256);

    function withdrawalsOf(uint256 epoch, address account) external view returns (uint256);
}

contract SymbioticCollector is IDistributionCollector {
    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        ISymbioticVault vault = ISymbioticVault(abi.decode(deployment, (address)));
        balances = new Balance[](1);
        uint256 amount = vault.activeBalanceOf(holder);
        uint256 currentEpoch = vault.currentEpoch();
        for (uint256 epoch = 0; epoch <= currentEpoch; epoch++) {
            amount += vault.withdrawalsOf(epoch, holder);
        }
        balances[0] =
            Balance({asset: vault.collateral(), balance: int256(amount), metadata: "SymbioticVault", holder: holder});
    }
}
