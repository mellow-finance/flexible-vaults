// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

import "../../../common/interfaces/IFluidVaultT1Resolver.sol";

contract FluidCollector is IDistributionCollector {
    IFluidVaultT1Resolver public immutable resolver;

    constructor(address resolver_) {
        resolver = IFluidVaultT1Resolver(resolver_);
    }

    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        uint256 nftId = abi.decode(deployment, (uint256));
        (IFluidVaultT1Resolver.UserPosition memory userPosition, IFluidVaultT1Resolver.VaultEntireData memory vaultData)
        = resolver.positionByNftId(nftId);
        if (userPosition.owner != holder) {
            return balances;
        }

        balances = new Balance[](2);
        balances[0] = Balance({
            asset: vaultData.constantVariables.supplyToken,
            balance: int256(userPosition.beforeSupply),
            metadata: "FluidCollateral",
            holder: holder
        });
        balances[1] = Balance({
            asset: vaultData.constantVariables.borrowToken,
            balance: -int256(userPosition.beforeBorrow),
            metadata: "FluidDebt",
            holder: holder
        });
    }
}
