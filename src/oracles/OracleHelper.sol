// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../vaults/Vault.sol";

contract OracleHelper {
    struct AssetPrice {
        address asset;
        /**
         * Price of the asset expressed via the base asset.
         * If the price is 0, it means that the asset is the base asset, then for other assets:
         * - If priceD18 = 1e18, it means that 1 asset = 1 base asset
         * - If priceD18 = 0.5e18, it means that 1 asset = 0.5 base asset
         * - If priceD18 = 2e18, it means that 1 asset = 2 base assets
         */
        uint256 priceD18;
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
        uint256 baseAssetIndex = type(uint256).max;
        pricesD18 = new uint256[](assetPrices.length);
        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (0 < i && assetPrices[i].asset <= assetPrices[i - 1].asset) {
                revert("OracleHelper: invalid asset order");
            }
            if (assetPrices[i].priceD18 == 0) {
                if (baseAssetIndex < type(uint256).max) {
                    revert("OracleHelper: multiple base assets");
                }
                baseAssetIndex = i;
            }
        }

        // Step 2. Process withdrawal queues.
        // Calculate total demand assets (expressed via the base asset) and unprocessed shares.
        IFeeManager feeManager = vault.feeManager();
        {
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
                    (,, uint256 demand_,) = IRedeemQueue(queue).getState();
                    if (assetPrice.priceD18 == 0) {
                        totalAssets -= demand_;
                    } else {
                        totalAssets -= Math.mulDiv(demand_, assetPrice.priceD18, 1 ether);
                    }
                }
            }
        }

        // Step 3. Calculate the price of the base asset.
        uint256 shares =
            vault.shareManager().totalShares() - vault.shareManager().activeSharesOf(feeManager.feeRecipient());
        uint256 minPriceD18 = feeManager.minPriceD18(address(vault));

        address baseAsset = feeManager.baseAsset(address(vault));
        pricesD18[baseAssetIndex] = Math.mulDiv(
            shares + feeManager.calculateFee(address(vault), baseAsset, minPriceD18, shares), 1 ether, totalAssets
        );

        if (baseAsset != address(0)) {
            if (assetPrices[baseAssetIndex].asset != baseAsset) {
                revert("OracleHelper: invalid base asset");
            }
            if (0 < minPriceD18 && pricesD18[baseAssetIndex] < minPriceD18) {
                pricesD18[baseAssetIndex] =
                    _find(feeManager, vault, pricesD18[baseAssetIndex], minPriceD18, baseAsset, shares, totalAssets);
            }
        }

        // Step 4. Calculate the price of the other assets based on the base asset.
        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (i != baseAssetIndex) {
                pricesD18[i] = Math.mulDiv(pricesD18[baseAssetIndex], assetPrices[i].priceD18, 1 ether);
            }
            if (pricesD18[i] > type(uint224).max || pricesD18[i] == 0) {
                revert("OracleHelper: invalid price");
            }
        }
    }

    function _find(
        IFeeManager feeManager,
        Vault vault,
        uint256 left,
        uint256 right,
        address baseAsset,
        uint256 shares,
        uint256 assets
    ) internal view returns (uint256 basePriceD18) {
        uint256 mid;
        basePriceD18 = right;
        while (left <= right) {
            mid = (left + right) >> 1;
            uint256 fee = feeManager.calculateFee(address(vault), baseAsset, mid, shares);
            if (Math.mulDiv(shares + fee, 1 ether, assets) <= mid) {
                basePriceD18 = mid;
                if (mid == 0) {
                    break;
                }
                right = mid - 1;
            } else {
                left = mid + 1;
            }
        }
    }
}
