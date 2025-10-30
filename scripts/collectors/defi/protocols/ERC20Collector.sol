// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

contract ERC20Collector is IDistributionCollector {
    function getDistributions(address holder, bytes memory, /* deployment */ address[] memory assets)
        external
        view
        returns (Balance[] memory balances)
    {
        balances = new Balance[](assets.length);
        uint256 iterator = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 balance = TransferLibrary.balanceOf(assets[i], holder);
            if (balance != 0) {
                balances[iterator++] =
                    Balance({asset: assets[i], balance: int256(balance), metadata: "ERC20", holder: holder});
            }
        }
        assembly {
            mstore(balances, iterator)
        }
    }
}
