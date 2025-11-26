// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

import "../../../common/interfaces/ICapLender.sol";

contract CapLenderCollector is IDistributionCollector {
    ICapLender public immutable lender;

    constructor(address lender_) {
        lender = ICapLender(lender_);
    }

    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        address[] memory assets = abi.decode(deployment, (address[]));

        uint256 iterator = 0;
        balances = new Balance[](assets.length);
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 debt = lender.debt(holder, assets[i]);
            if (debt > 0) {
                balances[iterator++] =
                    Balance({asset: assets[i], balance: -int256(debt), metadata: "CapDebt", holder: holder});
            }
        }
        assembly {
            mstore(balances, iterator)
        }
    }
}
