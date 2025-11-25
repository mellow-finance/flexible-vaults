// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ArraysLibrary} from "../../../common/ArraysLibrary.sol";
import {IDistributionCollector} from "./IDistributionCollector.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract ERC4626Collector is IDistributionCollector {
    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        address[] memory tokens = abi.decode(deployment, (address[]));
        balances = new Balance[](tokens.length);
        uint256 iterator = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 value = IERC4626(tokens[i]).previewRedeem(IERC4626(tokens[i]).balanceOf(holder));
            if (value > 0) {
                balances[iterator++] = Balance({
                    asset: IERC4626(tokens[i]).asset(),
                    balance: int256(value),
                    metadata: string.concat("ERC4626(", IERC4626(tokens[i]).symbol(), ")"),
                    holder: holder
                });
            }
        }
        assembly {
            mstore(balances, iterator)
        }
    }
}
