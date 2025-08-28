// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../src/interfaces/managers/IFeeManager.sol";
import "../../src/interfaces/managers/IRiskManager.sol";
import "../../src/interfaces/managers/IShareManager.sol";
import "../../src/interfaces/oracles/IOracle.sol";

import "../../src/interfaces/queues/IDepositQueue.sol";
import "../../src/interfaces/queues/IRedeemQueue.sol";
import "../../src/vaults/Vault.sol";
import "./IPriceOracle.sol";

contract Collector is Ownable {
    struct Withdrawal {
        address queue;
        address asset;
        uint256 shares;
        uint256 assets;
        bool isTimestamp; // always true
        uint256 claimingTime; // estimation, not the precise value!
    }

    struct Response {
        address vault;
        address baseAsset;
        address[] assets;
        uint8[] assetDecimals;
        uint256[] assetPrices;
        address[] depositQueues;
        address[] redeemQueues;
        uint256 totalLP;
        uint256 limitLP;
        uint256 userLP;
        uint256 totalBase;
        uint256 limitBase;
        uint256 userBase;
        uint256 lpPriceBase;
        uint256 totalUSD;
        uint256 limitUSD;
        uint256 userUSD;
        uint256 lpPriceUSD;
        Withdrawal[] withdrawals;
        uint256 blockNumber;
        uint256 timestamp;
    }

    struct FetchDepositAmountsResponse {
        bool isDepositPossible;
        bool isDepositorWhitelisted;
        bool isMerkleProofRequired;
        address asset;
        uint256 expectedLpAmount;
        uint256 expectedLpAmountUSDC;
        uint256 expectedAmount;
        uint256 expectedAmountUSDC;
    }

    address public immutable USD = address(bytes20(keccak256("usd-token-address")));

    IPriceOracle public oracle;

    constructor(address oracle_, address owner_) Ownable(owner_) {
        oracle = IPriceOracle(oracle_);
    }

    function setOracle(address oracle_) external onlyOwner {
        oracle = IPriceOracle(oracle_);
    }

    function collect(address user, Vault vault, address baseAssetFallback) public view returns (Response memory r) {
        r.vault = address(vault);
        r.blockNumber = block.number;
        r.timestamp = block.timestamp;

        IShareManager shareManager = vault.shareManager();
        IFeeManager feeManager = vault.feeManager();
        IRiskManager riskManager = vault.riskManager();
        IOracle vaultOracle = vault.oracle();

        r.baseAsset = feeManager.baseAsset(address(vault));
        if (r.baseAsset == address(0)) {
            r.baseAsset = baseAssetFallback;
        }

        {
            uint256 n = vaultOracle.supportedAssets();
            r.assets = new address[](n);
            r.assetDecimals = new uint8[](n);
            r.assetPrices = new uint256[](n);
            for (uint256 i = 0; i < n; i++) {
                r.assets[i] = vaultOracle.supportedAssetAt(i);
                r.assetDecimals[i] = IERC20Metadata(r.assets[i]).decimals();
                r.assetPrices[i] = oracle.priceX96(r.assets[i]);
            }
        }

        r.totalLP = shareManager.totalShares();
        r.userLP = shareManager.sharesOf(user);

        uint224 vaultBasePriceD18 = vaultOracle.getReport(r.baseAsset).priceD18;
        if (vaultBasePriceD18 > 0) {
            r.totalBase = Math.mulDiv(r.totalLP, 1 ether, vaultBasePriceD18);
            r.userBase = Math.mulDiv(r.userLP, 1 ether, vaultBasePriceD18);

            r.totalUSD = oracle.getValue(r.baseAsset, USD, r.totalBase);
            r.userUSD = oracle.getValue(r.baseAsset, USD, r.userBase);
        }

        IRiskManager.State memory vaultState = riskManager.vaultState();
        int256 remainingLimit = vaultState.limit - vaultState.balance;
        if (remainingLimit < 0) {
            remainingLimit = 0;
        }
        r.limitLP = uint256(remainingLimit) + r.totalLP;

        r.limitBase = Math.mulDiv(r.limitLP, 1 ether, vaultBasePriceD18);
        r.lpPriceBase = 1e36 / vaultBasePriceD18;

        r.limitUSD = oracle.getValue(r.baseAsset, USD, r.limitBase);
        r.lpPriceUSD = oracle.getValue(r.baseAsset, USD, r.lpPriceBase);

        r.withdrawals = _collectWithdrawals(vault, user);
    }

    function _collectWithdrawals(Vault vault, address user) private view returns (Withdrawal[] memory) {
        // // Count total withdrawals
        // uint256 totalWithdrawals = 0;
        // uint256 assetCount = vault.getAssetCount();

        // for (uint256 i = 0; i < assetCount; i++) {
        //     address asset = vault.assetAt(i);
        //     uint256 queueCount = vault.getQueueCount(asset);

        //     for (uint256 j = 0; j < queueCount; j++) {
        //         address queue = vault.queueAt(asset, j);
        //         if (!vault.isDepositQueue(queue)) {
        //             IRedeemQueue.Request[] memory requests = IRedeemQueue(queue).requestsOf(user, 0, 100);
        //             totalWithdrawals += requests.length;
        //         }
        //     }
        // }

        // // Collect the actual withdrawals
        // Withdrawal[] memory withdrawals = new Withdrawal[](totalWithdrawals);
        // uint256 withdrawalIndex = 0;

        // for (uint256 i = 0; i < assetCount; i++) {
        //     address asset = vault.assetAt(i);
        //     uint256 queueCount = vault.getQueueCount(asset);

        //     for (uint256 j = 0; j < queueCount; j++) {
        //         address queue = vault.queueAt(asset, j);
        //         if (!vault.isDepositQueue(queue)) {
        //             IRedeemQueue.Request[] memory requests = IRedeemQueue(queue).requestsOf(user, 0, 100);
        //             for (uint256 k = 0; k < requests.length; k++) {
        //                 withdrawals[withdrawalIndex] = Withdrawal({
        //                     queue: queue,
        //                     asset: asset,
        //                     timestamp: requests[k].timestamp,
        //                     shares: requests[k].shares,
        //                     assets: requests[k].assets,
        //                     isClaimable: requests[k].isClaimable
        //                 });
        //                 withdrawalIndex++;
        //             }
        //         }
        //     }
        // }

        // return withdrawals;
    }

    function collect(address user, address[] memory vaults, address baseAsset)
        public
        view
        returns (Response[] memory responses)
    {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, Vault(payable(vaults[i])), baseAsset);
        }
    }

    function multiCollect(address[] calldata users, address[] calldata vaults, address baseAsset)
        external
        view
        returns (Response[][] memory responses)
    {
        responses = new Response[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            responses[i] = collect(users[i], vaults, baseAsset);
        }
    }

    function fetchDepositAmounts(uint256 assets, address queue, address account)
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
        {
            // Check whitelist
            IShareManager shareManager = shareModule.shareManager();
            if (!shareManager.accounts(account).canDeposit && shareManager.flags().hasWhitelist) {
                return r;
            }

            r.isMerkleProofRequired = shareManager.whitelistMerkleRoot() != bytes32(0);
            r.isDepositorWhitelisted = true;
            r.asset = depositQueue.asset();
        }

        IOracle vaultOracle = shareModule.oracle();
        uint224 priceD18 = vaultOracle.getReport(r.asset).priceD18;

        IFeeManager feeManager = shareModule.feeManager();
        uint256 feePriceD18 = feeManager.calculateDepositFee(priceD18);
        uint256 reducedPriceD18 = priceD18 - feePriceD18;

        r.expectedAmount = assets;
        r.expectedLpAmount = Math.mulDiv(assets, reducedPriceD18, 1 ether);

        r.expectedAmountUSDC = oracle.getValue(r.asset, USD, assets);
        r.expectedLpAmountUSDC = r.expectedAmountUSDC - feeManager.calculateDepositFee(r.expectedAmountUSDC);
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
