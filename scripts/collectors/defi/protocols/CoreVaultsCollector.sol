// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/vaults/Vault.sol";
import "./IDistributionCollector.sol";

contract CoreVaultsCollector is IDistributionCollector {
    struct Stack {
        Vault vault;
        address withdrawAsset;
        uint256 shares;
        uint256 assets;
    }

    function getDistributions(address holder, bytes memory deployment, address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        Stack memory $;
        {
            address vault_;
            (vault_, $.withdrawAsset) = abi.decode(deployment, (address, address));
            $.vault = Vault(payable(vault_));
        }

        $.shares = $.vault.shareManager().sharesOf(holder);
        $.assets = $.vault.getAssetCount();
        balances = new Balance[]($.assets);
        uint256 withdrawAssetIndex = type(uint256).max;
        for (uint256 i = 0; i < $.assets; i++) {
            address asset = $.vault.assetAt(i);
            balances[i] = Balance({asset: asset, balance: 0, metadata: "CoreVault", holder: holder});
            for (uint256 j = 0; j < $.vault.getQueueCount(asset); j++) {
                address queue = $.vault.queueAt(asset, j);
                if ($.vault.isDepositQueue(queue)) {
                    (, uint256 assets_) = IDepositQueue(queue).requestOf(holder);
                    if (assets_ == 0) {
                        continue;
                    }
                    if (IDepositQueue(queue).claimableOf(holder) != 0) {
                        continue;
                    }
                    balances[i].balance += int256(assets_);
                } else {
                    (uint256 assets_, uint256 shares_) = analyzeRequests(queue, holder);
                    balances[i].balance += int256(assets_);
                    $.shares += shares_;
                    if ($.withdrawAsset == asset) {
                        withdrawAssetIndex = i;
                    }
                }
            }
        }

        if ($.shares > 0) {
            if (withdrawAssetIndex == type(uint256).max) {
                revert("CoreVaultsCollector: unsupported withdraw asset");
            }
            IOracle.DetailedReport memory report = $.vault.oracle().getReport($.withdrawAsset);
            if (report.isSuspicious) {
                revert("CoreVaultsCollector: withdraw asset report is suspicious");
            }
            balances[withdrawAssetIndex].balance += int256(Math.mulDiv($.shares, 1 ether, report.priceD18));
        }

        uint256 iterator = 0;
        for (uint256 i = 0; i < $.assets; i++) {
            if (balances[i].balance == 0) {
                continue;
            }
            balances[iterator++] = balances[i];
        }
        assembly {
            mstore(balances, iterator)
        }
    }

    function analyzeRequests(address queue, address holder) public view returns (uint256 assets, uint256 shares) {
        IRedeemQueue.Request[] memory requests = IRedeemQueue(queue).requestsOf(holder, 0, type(uint256).max);
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i].isClaimable || requests[i].assets != 0) {
                assets += requests[i].assets;
            } else {
                shares += requests[i].shares;
            }
        }
    }
}
