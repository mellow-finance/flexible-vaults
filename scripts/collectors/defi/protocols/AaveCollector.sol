// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../external/IAaveOracleV3.sol";
import "../external/IAavePoolV3.sol";
import "./IDistributionCollector.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveCollector is IDistributionCollector {
    struct ProtocolDeployment {
        address pool;
        string metadata;
    }

    function getDistributions(address holder, bytes memory deployment, address[] memory assets)
        external
        view
        returns (Balance[] memory balances)
    {
        ProtocolDeployment memory aave = abi.decode(deployment, (ProtocolDeployment));
        IAavePoolV3.ReserveDataLegacy memory data;
        IAavePoolV3 instance = IAavePoolV3(aave.pool);
        balances = new Balance[](assets.length * 2);
        uint256 iterator = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            data = instance.getReserveData(assets[i]);
            if (data.aTokenAddress != address(0)) {
                uint256 collateral = IERC20(data.aTokenAddress).balanceOf(holder);
                if (collateral != 0) {
                    balances[iterator++] = Balance({
                        asset: assets[i],
                        balance: int256(collateral),
                        metadata: string(abi.encodePacked("Aave", aave.metadata, "Collateral")),
                        holder: holder
                    });
                }
            }
            if (data.variableDebtTokenAddress != address(0)) {
                uint256 debt = IERC20(data.variableDebtTokenAddress).balanceOf(holder);
                if (debt != 0) {
                    balances[iterator++] = Balance({
                        asset: assets[i],
                        balance: -int256(debt),
                        metadata: string(abi.encodePacked("Aave", aave.metadata, "Debt")),
                        holder: holder
                    });
                }
            }
        }
        assembly {
            mstore(balances, iterator)
        }
    }
}
