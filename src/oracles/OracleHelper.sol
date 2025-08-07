// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../vaults/Vault.sol";

contract OracleHelper {
    struct AssetPrice {
        address asset;
        uint256 priceD18;
    }

    struct Stack {
        uint256 baseAssetIndex;
        address baseAsset;
        uint256 unprocessedShares;
        uint256 totalRedeemDemand;
    }

    function getPricesD18(Vault vault, uint256 totalAssets, AssetPrice[] calldata assetPrices)
        external
        view
        returns (uint256[] memory pricesD18)
    {
        Stack memory $;
        $.baseAssetIndex = type(uint256).max;
        pricesD18 = new uint256[](assetPrices.length);
        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (i > 0 && assetPrices[i].asset <= assetPrices[i - 1].asset) {
                revert("OracleHelper: invalid asset order");
            }
            if (assetPrices[i].priceD18 == 0) {
                if ($.baseAssetIndex < type(uint256).max) {
                    revert("OracleHelper: multiple base assets");
                }
                $.baseAssetIndex = i;
                break;
            }
        }
        IFeeManager feeManager = vault.feeManager();
        $.baseAsset = assetPrices[$.baseAssetIndex].asset;

        uint256 queueAssets = vault.getAssetCount();
        for (uint256 i = 0; i < queueAssets; i++) {
            address queueAsset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(queueAsset);
            AssetPrice calldata assetPrice = find(assetPrices, queueAsset);
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

        for (uint256 i = 0; i < assetPrices.length; i++) {
            if (i == $.baseAssetIndex) {
                continue;
            }
            pricesD18[i] = Math.mulDiv(pricesD18[$.baseAssetIndex], assetPrices[i].priceD18, 1 ether);
        }
    }

    function find(AssetPrice[] calldata assetPrices, address asset) public pure returns (AssetPrice calldata) {
        if (assetPrices.length == 0) {
            revert("OracleHelper: asset not found");
        }
        uint256 left = 0;
        uint256 right = assetPrices.length - 1;
        uint256 mid;
        while (left <= right) {
            mid = (left + right) >> 1;
            if (assetPrices[mid].asset <= asset) {
                if (assetPrices[mid].asset == asset) {
                    return assetPrices[mid];
                }
                left = mid + 1;
            } else {
                if (mid == 0) {
                    break;
                }
                right = mid - 1;
            }
        }
        revert("OracleHelper: asset not found");
    }
}
