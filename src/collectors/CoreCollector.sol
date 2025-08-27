// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/managers/IFeeManager.sol";
import "../interfaces/managers/IRiskManager.sol";
import "../interfaces/managers/IShareManager.sol";
import "../interfaces/oracles/IOracle.sol";

import "../interfaces/queues/IDepositQueue.sol";
import "../interfaces/queues/IRedeemQueue.sol";
import "../vaults/Vault.sol";
import "./IPriceOracle.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract CoreCollector {
    address public immutable USD = address(bytes20(keccak256("usd-token-address")));

    IPriceOracle public oracle;

    constructor(address oracle_) {
        oracle = IPriceOracle(oracle_);
    }

    struct Withdrawal {
        address queue;
        address asset;
        uint256 timestamp;
        uint256 shares;
        uint256 assets;
        bool isClaimable;
    }

    struct Response {
        address vault;
        address asset; // Base asset
        uint8 assetDecimals; // Base asset decimals
        uint256 assetPriceX96; // Base asset price in Q96
        uint256 totalLP; // Total shares
        uint256 totalUSD; // Total assets in USD
        uint256 totalInBaseAsset; // Total assets in base asset
        uint256 limitLP; // Limit shares
        uint256 limitUSD; // Limit assets in USD
        uint256 limitInBaseAsset; // Limit assets in base asset
        uint256 userLP; // User shares
        uint256 userUSD; // User assets in USD
        uint256 userInBaseAsset; // User assets in base asset
        uint256 lpPriceUSD; // Price of 1 share in USD
        uint256 lpPriceInBaseAsset; // Price of 1 share in base asset
        Withdrawal[] withdrawals; // Withdrawals
        uint256 blockNumber; // Block number
        uint256 timestamp; // Timestamp
    }

    struct FetchDepositAmountsResponse {
        bool isDepositPossible;
        bool isDepositorWhitelisted;
        uint256[] ratiosD18;
        address[] tokens;
        uint256 expectedLpAmount;
        uint256 expectedLpAmountUSDC;
        uint256[] expectedAmounts;
        uint256[] expectedAmountsUSDC;
    }

    function collect(address user, Vault vault) public view returns (Response memory r) {
        r.vault = address(vault);
        r.blockNumber = block.number;
        r.timestamp = block.timestamp;

        IShareManager shareManager = vault.shareManager();
        IFeeManager feeManager = vault.feeManager();
        IRiskManager riskManager = vault.riskManager();
        IOracle vaultOracle = vault.oracle();

        r.asset = feeManager.baseAsset(address(vault));

        // If no base asset is set, try to use the first supported asset in oracle (or pass it via args?)
        if (r.asset == address(0) && vaultOracle.supportedAssets() > 0) {
            r.asset = vaultOracle.supportedAssetAt(0);
        }

        if (r.asset != address(0)) {
            r.assetDecimals = IERC20Metadata(r.asset).decimals();
            r.assetPriceX96 = oracle.priceX96(r.asset);
        }

        // Get total shares and user shares
        r.totalLP = shareManager.totalShares();
        r.userLP = shareManager.sharesOf(user);

        // Calculate total assets in base asset using vault oracle price
        // shares = assets * priceD18 / 1e18 => assets = shares * 1e18 / priceD18
        IOracle.DetailedReport memory report = vaultOracle.getReport(r.asset);
        uint256 priceD18 = report.priceD18;

        if (priceD18 > 0) {
            r.totalInBaseAsset = Math.mulDiv(r.totalLP, 1 ether, priceD18);
            r.userInBaseAsset = Math.mulDiv(r.userLP, 1 ether, priceD18);

            // Calculate USD values using external Oracle
            r.totalUSD = oracle.getValue(r.asset, USD, r.totalInBaseAsset);
            r.userUSD = oracle.getValue(r.asset, USD, r.userInBaseAsset);
        }

        // Get vault limit from RiskManager
        IRiskManager.State memory vaultState = riskManager.vaultState();
        if (vaultState.limit > 0) {
            // Convert limit (which is in shares) to assets
            r.limitLP = vaultState.limit > 0 ? uint256(vaultState.limit) : type(uint256).max;
            if (priceD18 > 0 && r.limitLP < type(uint256).max) {
                r.limitInBaseAsset = Math.mulDiv(r.limitLP, 1 ether, priceD18);
                r.limitUSD = oracle.getValue(r.asset, USD, r.limitInBaseAsset);
            } else {
                r.limitInBaseAsset = type(uint256).max;
                r.limitUSD = type(uint256).max;
            }
        } else {
            r.limitLP = type(uint256).max;
            r.limitInBaseAsset = type(uint256).max;
            r.limitUSD = type(uint256).max;
        }

        // Calculate LP prices
        if (r.totalLP > 0) {
            r.lpPriceUSD = Math.mulDiv(1 ether, r.totalUSD, r.totalLP);
            r.lpPriceInBaseAsset = Math.mulDiv(1 ether, r.totalInBaseAsset, r.totalLP);
        }

        // Collect withdrawal information from redeem queues (?)
        r.withdrawals = _collectWithdrawals(vault, user);
    }

    function _collectWithdrawals(Vault vault, address user) private view returns (Withdrawal[] memory) {
        // Count total withdrawals
        uint256 totalWithdrawals = 0;
        uint256 assetCount = vault.getAssetCount();

        for (uint256 i = 0; i < assetCount; i++) {
            address asset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(asset);

            for (uint256 j = 0; j < queueCount; j++) {
                address queue = vault.queueAt(asset, j);
                if (!vault.isDepositQueue(queue)) {
                    IRedeemQueue.Request[] memory requests = IRedeemQueue(queue).requestsOf(user, 0, 100);
                    totalWithdrawals += requests.length;
                }
            }
        }

        // Collect the actual withdrawals
        Withdrawal[] memory withdrawals = new Withdrawal[](totalWithdrawals);
        uint256 withdrawalIndex = 0;

        for (uint256 i = 0; i < assetCount; i++) {
            address asset = vault.assetAt(i);
            uint256 queueCount = vault.getQueueCount(asset);

            for (uint256 j = 0; j < queueCount; j++) {
                address queue = vault.queueAt(asset, j);
                if (!vault.isDepositQueue(queue)) {
                    IRedeemQueue.Request[] memory requests = IRedeemQueue(queue).requestsOf(user, 0, 100);
                    for (uint256 k = 0; k < requests.length; k++) {
                        withdrawals[withdrawalIndex] = Withdrawal({
                            queue: queue,
                            asset: asset,
                            timestamp: requests[k].timestamp,
                            shares: requests[k].shares,
                            assets: requests[k].assets,
                            isClaimable: requests[k].isClaimable
                        });
                        withdrawalIndex++;
                    }
                }
            }
        }

        return withdrawals;
    }

    function collect(address user, address[] memory vaults) public view returns (Response[] memory responses) {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, Vault(payable(vaults[i])));
        }
    }

    function multiCollect(address[] calldata users, address[] calldata vaults)
        external
        view
        returns (Response[][] memory responses)
    {
        responses = new Response[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            responses[i] = collect(users[i], vaults);
        }
    }

    function fetchDepositAmounts(uint256[] memory amounts, address queue, address user)
        external
        view
        returns (FetchDepositAmountsResponse memory r)
    {
        // Check if queue is paused
        IDepositQueue depositQueue = IDepositQueue(queue);
        address vault = depositQueue.vault();
        IShareModule shareModule = IShareModule(vault);

        if (shareModule.isPausedQueue(queue)) {
            return r;
        }
        r.isDepositPossible = true;

        // Check whitelist
        IShareManager shareManager = shareModule.shareManager();
        bytes32[] memory emptyProof = new bytes32[](0);
        if (!shareManager.isDepositorWhitelisted(user, emptyProof)) {
            return r;
        }
        r.isDepositorWhitelisted = true;

        // Get asset
        address asset = depositQueue.asset();
        r.tokens = new address[](1);
        r.tokens[0] = asset;
        r.ratiosD18 = new uint256[](1);
        r.ratiosD18[0] = 1 ether;

        // Calculate expected LP amount using oracle price
        // shares = Math.mulDiv(assets, priceD18 - fee, 1 ether)
        IOracle vaultOracle = shareModule.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(asset);
        uint256 priceD18 = report.priceD18;
        if (priceD18 > 0) {
            IFeeManager feeManager = shareModule.feeManager();
            uint256 feePriceD18 = feeManager.calculateDepositFee(priceD18);
            uint256 reducedPriceD18 = priceD18 - feePriceD18;

            r.expectedLpAmount = Math.mulDiv(amounts[0], reducedPriceD18, 1 ether);
            r.expectedLpAmountUSDC = oracle.getValue(asset, USD, amounts[0]); // IDK
        }
        r.expectedAmounts = new uint256[](1);
        r.expectedAmounts[0] = amounts[0];
        r.expectedAmountsUSDC = new uint256[](1);
        r.expectedAmountsUSDC[0] = r.expectedLpAmountUSDC;
    }

    function fetchWithdrawalAmounts(uint256 lpAmount, address queue)
        external
        view
        returns (uint256[] memory expectedAmounts, uint256[] memory expectedAmountsUSDC)
    {
        expectedAmounts = new uint256[](1);
        expectedAmountsUSDC = new uint256[](1);

        IRedeemQueue redeemQueue = IRedeemQueue(queue);
        address asset = redeemQueue.asset();

        // Apply redeem fee to shares estimate
        // TODO: Check if it does make sense (especially for the calculation using the batch)
        address vault = redeemQueue.vault();
        IShareModule shareModule = IShareModule(vault);
        IFeeManager feeManager = shareModule.feeManager();
        uint256 feeShares = feeManager.calculateRedeemFee(lpAmount);
        if (feeShares > lpAmount) {
            lpAmount = 0;
        } else {
            lpAmount -= feeShares;
        }

        // Get the latest batch to calculate conversion rate
        (, uint256 batchesLength,,) = redeemQueue.getState();
        if (batchesLength > 0) {
            (uint256 batchAssets, uint256 batchShares) = redeemQueue.batchAt(batchesLength - 1);
            if (batchShares > 0) {
                //  assets = shares * batchAssets / batchShares
                expectedAmounts[0] = Math.mulDiv(lpAmount, batchAssets, batchShares);
                expectedAmountsUSDC[0] = oracle.getValue(asset, USD, expectedAmounts[0]);
                return (expectedAmounts, expectedAmountsUSDC);
            }
        }

        // No batches yet (or no shares in batch), use oracle price
        IOracle vaultOracle = shareModule.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(asset);

        if (report.priceD18 > 0) {
            // assets = shares * 1e18 / priceD18
            expectedAmounts[0] = Math.mulDiv(lpAmount, 1 ether, report.priceD18);
            expectedAmountsUSDC[0] = oracle.getValue(asset, USD, expectedAmounts[0]);
        }
    }
}
