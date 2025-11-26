// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/libraries/TransferLibrary.sol";
import "../../../src/oracles/OracleHelper.sol";
import "../../../src/vaults/Vault.sol";

interface IWSTETH {
    function getStETHByWstETH(uint256) external view returns (uint256);
}

contract TqETHHelper {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function allAssets() public pure returns (address[] memory assets) {
        assets = new address[](3);
        assets[0] = ETH;
        assets[1] = WETH;
        assets[2] = WSTETH;
    }

    function get() external view returns (IOracle.Report[] memory reports) {
        Vault tqETH = Vault(payable(0xDbC81B33A23375A90c8Ba4039d5738CB6f56fE8d));
        OracleHelper oracleHelper = OracleHelper(0x000000005F543c38d5ea6D0bF10A50974Eb55E35);
        Vault strETH = Vault(payable(0x277C6A642564A91ff78b008022D65683cEE5CCC5));
        address[] memory assets = allAssets();
        (uint256[] memory amounts) = getPosition(strETH, address(tqETH));
        addERC20Balances(assets, amounts, address(tqETH));

        uint256 subvaults = tqETH.subvaults();
        for (uint256 i = 0; i < subvaults; i++) {
            address subvault = tqETH.subvaultAt(i);
            addERC20Balances(assets, amounts, subvault);
            uint256[] memory amounts_ = getPosition(strETH, subvault);
            for (uint256 j = 0; j < amounts_.length; j++) {
                amounts[j] += amounts_[j];
            }
        }

        uint256 totalAssets = amounts[0] + amounts[1] + IWSTETH(WSTETH).getStETHByWstETH(amounts[2]);

        OracleHelper.AssetPrice[] memory prices = new OracleHelper.AssetPrice[](3);
        prices[0].asset = WSTETH;
        prices[0].priceD18 = IWSTETH(WSTETH).getStETHByWstETH(1 ether);

        prices[1].asset = WETH;
        prices[1].priceD18 = 1 ether;

        prices[2].asset = ETH;

        uint256[] memory oraclePrices = oracleHelper.getPricesD18(tqETH, totalAssets, prices);
        reports = new IOracle.Report[](oraclePrices.length);

        for (uint256 i = 0; i < 3; i++) {
            reports[i].asset = assets[i];
            reports[i].priceD18 = uint224(oraclePrices[2 - i]);
        }
    }

    function addERC20Balances(address[] memory assets, uint256[] memory amounts, address holder) public view {
        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] += TransferLibrary.balanceOf(assets[i], holder);
        }
    }

    function getPosition(Vault vault, address holder) public view returns (uint256[] memory amounts) {
        uint256 shares = vault.shareManager().sharesOf(holder);
        IOracle oracle = vault.oracle();
        address[] memory assets = allAssets();
        amounts = new uint256[](assets.length);
        uint256 baseAssetIndex = type(uint256).max;
        address baseAsset = vault.feeManager().baseAsset(address(vault));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
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
            IOracle.DetailedReport memory report = oracle.getReport(baseAsset);
            if (report.isSuspicious) {
                revert("Suspicious report");
            }
            amounts[baseAssetIndex] += Math.mulDiv(shares, 1 ether, report.priceD18);
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
