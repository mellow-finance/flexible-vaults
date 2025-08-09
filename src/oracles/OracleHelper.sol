// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../vaults/Vault.sol";

contract OracleHelper {
    struct AssetPrice {
        address asset;
        /**
         * Price of the asset expressed via the base asset.
         * If the price is 0, it means that the asset is the base asset.
         * E.g.
         * - If priceD18 = 1e18, it means that 1 asset = 1 base asset
         * - If priceD18 = 0.5e18, it means that 1 asset = 0.5 base asset
         * - If priceD18 = 2e18, it means that 1 asset = 2 base asset
         */
        uint256 priceD18;
    }

    struct Stack {
        uint256 baseAssetIndex;
        address baseAsset;
        uint256 unprocessedShares;
        uint256 totalRedeemDemand;
    }

    /**
     * Calculates the prices of the vault's assets which will be reported to the oracle.
     * @param vault Vault to calculate the prices for.
     * @param totalAssets Total assets in the vault expressed via the base asset (TVL denominated in the base asset).
     * @param assetPrices Prices of the assets.
     */
    function getPricesD18(Vault vault, uint256 totalAssets, AssetPrice[] calldata assetPrices)
        external
        view
        returns (uint256[] memory pricesD18)
    {
        // Step 1. Find the base asset index.
        Stack memory $;
        $.baseAssetIndex = type(uint256).max;
        pricesD18 = new uint256[](assetPrices.length);
        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (0 < i && assetPrices[i].asset <= assetPrices[i - 1].asset) {
                revert("OracleHelper: invalid asset order");
            }
            if (assetPrices[i].priceD18 == 0) {
                if ($.baseAssetIndex < type(uint256).max) {
                    revert("OracleHelper: multiple base assets");
                }
                $.baseAssetIndex = i;
            }
        }

        // Step 2. Process withdrawal queues.
        // Calculate total demand assets (expressed via the base asset) and unprocessed shares.
        IFeeManager feeManager = vault.feeManager();
        $.baseAsset = assetPrices[$.baseAssetIndex].asset;

        uint256 queueAssets = vault.getAssetCount();
        for (uint256 i = 0; i < queueAssets; i++) {
            address queueAsset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(queueAsset);
            AssetPrice calldata assetPrice = assetPrices[0];
            for (uint256 j = 0; j < assetPrices.length; j++) {
                if (assetPrices[j].asset == queueAsset) {
                    assetPrice = assetPrices[j];
                    break;
                }
            }
            if (assetPrice.asset != queueAsset) {
                revert("OracleHelper: asset not found");
            }
            for (uint256 j = 0; j < queueCount; j++) {
                address queue = vault.queueAt(queueAsset, j);
                if (vault.isDepositQueue(queue) || IQueue(queue).canBeRemoved()) {
                    continue;
                }
                (,, uint256 demand_, uint256 shares_) = IRedeemQueue(queue).getState();
                $.unprocessedShares += shares_;
                if (assetPrice.priceD18 == 0) {
                    $.totalRedeemDemand += demand_;
                } else {
                    $.totalRedeemDemand += Math.mulDiv(demand_, 1 ether, assetPrice.priceD18);
                }
            }
        }

        // Step 3. Calculate the price of the base asset.
        if (feeManager.baseAsset(address(vault)) == address(0)) {
            pricesD18[$.baseAssetIndex] = Math.mulDiv(
                vault.shareManager().totalShares() + $.unprocessedShares, 1 ether, totalAssets - $.totalRedeemDemand
            );
        } else {
            if (feeManager.baseAsset(address(vault)) != $.baseAsset) {
                revert("OracleHelper: invalid base asset");
            }

            uint256 baseAssetPriceD18 = vault.oracle().getReport($.baseAsset).priceD18;
            uint256 totalShares = vault.shareManager().totalShares();
            while (true) {
                uint256 newBaseAssetPriceD18 = Math.mulDiv(
                    totalShares + $.unprocessedShares
                        + feeManager.calculateFee(address(vault), $.baseAsset, baseAssetPriceD18, totalShares),
                    1 ether,
                    totalAssets - $.totalRedeemDemand
                );
                if (newBaseAssetPriceD18 == baseAssetPriceD18) {
                    break;
                }
                baseAssetPriceD18 = newBaseAssetPriceD18;
            }
            pricesD18[$.baseAssetIndex] = baseAssetPriceD18;
        }

        // Step 4. Calculate the price of the other assets expressed via the base asset.
        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (i == $.baseAssetIndex) {
                continue;
            }
            pricesD18[i] = Math.mulDiv(pricesD18[$.baseAssetIndex], assetPrices[i].priceD18, 1 ether);
        }
    }
}
