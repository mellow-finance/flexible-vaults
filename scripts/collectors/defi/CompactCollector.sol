// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/oracles/OracleSubmitter.sol";
import "../../../src/vaults/Vault.sol";

contract CompactCollector {
    function getPosition(Vault vault, OracleSubmitter oracleSubmitter, address holder)
        external
        view
        returns (address[] memory assets, uint256[] memory amounts)
    {
        uint256 shares = vault.shareManager().sharesOf(holder);
        IOracle oracle = vault.oracle();
        assets = new address[](oracle.supportedAssets());
        amounts = new uint256[](assets.length);
        uint256 baseAssetIndex = type(uint256).max;
        address baseAsset = vault.feeManager().baseAsset(address(vault));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = oracle.supportedAssetAt(i);
            assets[i] = asset;
            uint256 queues = vault.getQueueCount(asset);
            for (uint256 j = 0; j < queues; j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    (, uint256 assets_) = IDepositQueue(queue).requestOf(holder);
                    if (assets_ == 0) {
                        continue;
                    }
                    if (IDepositQueue(queue).claimableOf(holder) != 0) {
                        continue;
                    }
                    amounts[i] += assets_;
                } else {
                    IRedeemQueue.Request[] memory requests =
                        IRedeemQueue(queue).requestsOf(holder, 0, type(uint256).max);
                    (uint256 assets_, uint256 shares_) = analyzeRequests(requests);
                    amounts[i] += assets_;
                    shares += shares_;
                }
            }
            if (asset == baseAsset) {
                baseAssetIndex = i;
            }
        }

        if (shares != 0) {
            if (address(oracleSubmitter) == address(0)) {
                IOracle.DetailedReport memory report = oracle.getReport(baseAsset);
                if (report.isSuspicious) {
                    revert("Suspicious report");
                }
                amounts[baseAssetIndex] += Math.mulDiv(shares, 1 ether, report.priceD18);
            } else {
                amounts[baseAssetIndex] +=
                    Math.mulDiv(shares, uint256(oracleSubmitter.latestAnswer()), 10 ** oracleSubmitter.decimals());
            }
        }
    }

    function analyzeRequests(IRedeemQueue.Request[] memory requests)
        public
        pure
        returns (uint256 assets, uint256 shares)
    {
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i].isClaimable || requests[i].assets != 0) {
                assets += requests[i].assets;
            } else {
                shares += requests[i].shares;
            }
        }
    }
}
