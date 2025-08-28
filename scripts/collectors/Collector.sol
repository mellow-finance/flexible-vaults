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
import "../../src/interfaces/queues/ISignatureQueue.sol";
import "../../src/vaults/Vault.sol";
import "./IPriceOracle.sol";

contract Collector is Ownable {
    struct Config {
        address baseAssetFallback;
        uint256 oracleUpdateInterval;
        uint256 redeemHandlingInterval;
    }

    struct Request {
        address queue;
        address asset;
        uint256 shares;
        uint256 assets;
        uint256 eta;
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
        uint256 accountLP;
        uint256 totalBase;
        uint256 limitBase;
        uint256 accountBase;
        uint256 lpPriceBase;
        uint256 totalUSD;
        uint256 limitUSD;
        uint256 accountUSD;
        uint256 lpPriceUSD;
        Request[] deposits;
        Request[] withdrawals;
        uint256 blockNumber;
        uint256 timestamp;
    }

    struct DepositParams {
        bool isDepositPossible;
        bool isDepositorWhitelisted;
        bool isMerkleProofRequired;
        address asset;
        uint256 shares;
        uint256 sharesUSDC;
        uint256 assets;
        uint256 assetsUSDC;
        uint256 eta;
    }

    struct WithdrawalParams {
        bool isWithdrawalPossible;
        address asset;
        uint256 shares;
        uint256 sharesUSDC;
        uint256 assets;
        uint256 assetsUSDC;
        uint256 eta;
    }

    address public immutable USD = address(bytes20(keccak256("usd-token-address")));

    IPriceOracle public oracle;
    uint256 public bufferSize = 256;

    constructor(address oracle_, address owner_) Ownable(owner_) {
        oracle = IPriceOracle(oracle_);
    }

    function setOracle(address oracle_) external onlyOwner {
        oracle = IPriceOracle(oracle_);
    }

    function setBufferSize(uint256 bufferSize_) external onlyOwner {
        bufferSize = bufferSize_;
    }

    function collect(address account, Vault vault, Config calldata config) public view returns (Response memory r) {
        r.vault = address(vault);
        r.blockNumber = block.number;
        r.timestamp = block.timestamp;

        IShareManager shareManager = vault.shareManager();
        IFeeManager feeManager = vault.feeManager();
        IRiskManager riskManager = vault.riskManager();
        IOracle vaultOracle = vault.oracle();

        r.baseAsset = feeManager.baseAsset(address(vault));
        if (r.baseAsset == address(0)) {
            r.baseAsset = config.baseAssetFallback;
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
        r.accountLP = shareManager.sharesOf(account);

        uint224 vaultBasePriceD18 = vaultOracle.getReport(r.baseAsset).priceD18;
        if (vaultBasePriceD18 > 0) {
            r.totalBase = Math.mulDiv(r.totalLP, 1 ether, vaultBasePriceD18);
            r.accountBase = Math.mulDiv(r.accountLP, 1 ether, vaultBasePriceD18);

            r.totalUSD = oracle.getValue(r.baseAsset, USD, r.totalBase);
            r.accountUSD = oracle.getValue(r.baseAsset, USD, r.accountBase);
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

        r.deposits = _collectDeposits(vault, account, config);
        r.withdrawals = _collectWithdrawals(vault, account, config);
    }

    function _collectDeposits(Vault vault, address account, Config calldata config)
        private
        view
        returns (Request[] memory requests)
    {
        requests = new Request[](vault.getQueueCount());
        uint256 iterator = 0;
        IOracle.SecurityParams memory securityParams = vault.oracle().securityParams();
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            IOracle.DetailedReport memory report = vault.oracle().getReport(asset);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (!vault.isDepositQueue(queue)) {
                    continue;
                }
                try ISignatureQueue(queue).consensus() {
                    continue;
                } catch {}
                (uint256 timestamp, uint256 assets) = IDepositQueue(queue).requestOf(account);
                if (assets == 0) {
                    continue;
                }
                requests[iterator] = Request({
                    queue: queue,
                    asset: asset,
                    shares: IDepositQueue(queue).claimableOf(account),
                    assets: assets,
                    eta: 0
                });
                if (requests[iterator].shares == 0) {
                    requests[iterator].shares = Math.mulDiv(assets, report.priceD18, 1 ether);
                    requests[iterator].eta = _findNextTimestamp(
                        report.timestamp, timestamp, securityParams.depositInterval, config.oracleUpdateInterval
                    );
                }
                iterator++;
            }
        }
        assembly {
            mstore(requests, iterator)
        }
    }

    function _collectWithdrawals(Vault vault, address account, Config calldata config)
        private
        view
        returns (Request[] memory requests)
    {
        requests = new Request[](bufferSize);
        uint256 iterator = 0;
        IOracle.SecurityParams memory securityParams = vault.oracle().securityParams();
        for (uint256 i = 0; i < vault.getAssetCount(); i++) {
            address asset = vault.assetAt(i);
            IOracle.DetailedReport memory report = vault.oracle().getReport(asset);
            for (uint256 j = 0; j < vault.getQueueCount(asset); j++) {
                address queue = vault.queueAt(asset, j);
                if (vault.isDepositQueue(queue)) {
                    continue;
                }
                try ISignatureQueue(queue).consensus() {
                    continue;
                } catch {}
                IRedeemQueue.Request[] memory redeemRequests =
                    IRedeemQueue(queue).requestsOf(account, 0, requests.length);
                for (uint256 k = 0; k < redeemRequests.length; k++) {
                    requests[iterator] = Request({
                        queue: queue,
                        asset: asset,
                        shares: redeemRequests[k].shares,
                        assets: redeemRequests[k].assets,
                        eta: 0
                    });
                    if (redeemRequests[k].isClaimable) {} else if (redeemRequests[k].assets != 0) {
                        requests[iterator].eta = block.timestamp + config.redeemHandlingInterval;
                    } else {
                        requests[iterator].assets = Math.mulDiv(redeemRequests[k].shares, 1 ether, report.priceD18);
                        requests[iterator].eta = _findNextTimestamp(
                            report.timestamp,
                            redeemRequests[k].timestamp,
                            securityParams.redeemInterval,
                            config.oracleUpdateInterval
                        ) + config.redeemHandlingInterval;
                    }
                    iterator++;
                }
            }
        }
        assembly {
            mstore(requests, iterator)
        }
    }

    function _findNextTimestamp(
        uint256 reportTimestamp,
        uint256 requestTimestamp,
        uint256 oracleInterval,
        uint256 oracleUpdateInterval
    ) internal view returns (uint256) {
        uint256 latestOracleUpdate = reportTimestamp == 0 ? block.timestamp : reportTimestamp;
        uint256 minEligibleTimestamp = requestTimestamp + oracleInterval;
        uint256 delta = minEligibleTimestamp < latestOracleUpdate ? 0 : minEligibleTimestamp - latestOracleUpdate;
        return latestOracleUpdate
            + Math.max(oracleUpdateInterval, delta * (oracleUpdateInterval - 1) / oracleUpdateInterval);
    }

    function collect(address user, address[] memory vaults, Config calldata config)
        public
        view
        returns (Response[] memory responses)
    {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, Vault(payable(vaults[i])), config);
        }
    }

    function multiCollect(address[] calldata users, address[] calldata vaults, Config calldata config)
        external
        view
        returns (Response[][] memory responses)
    {
        responses = new Response[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            responses[i] = collect(users[i], vaults, config);
        }
    }

    function getDepositParams(address queue, uint256 assets, address account, Config calldata config)
        external
        view
        returns (DepositParams memory r)
    {
        IDepositQueue depositQueue = IDepositQueue(queue);
        address vault = depositQueue.vault();
        IShareModule shareModule = IShareModule(vault);
        if (shareModule.isPausedQueue(queue)) {
            return r;
        }
        IOracle vaultOracle = shareModule.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(r.asset);
        if (report.isSuspicious || report.timestmap == 0) {
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

        r.assets = assets;
        r.assetsUSDC = oracle.getValue(r.asset, USD, r.assets);

        r.shares = Math.mulDiv(assets, report.priceD18, 1 ether);
        r.sharesUSDC = oracle.getValue(r.asset, USD, r.sharesUSDC);

        IFeeManager feeManager = shareModule.feeManager();
        if (feeManager.depositFeeD6() != 0) {
            r.shares -= feeManager.calculateDepositFee(r.shares);
            r.sharesUSDC -= feeManager.calculateDepositFee(r.sharesUSDC);
        }

        r.eta = _findNextTimestamp(
            report.timestamp, block.timestamp, vaultOracle.securityParams().depositInterval, config.oracleUpdateInterval
        );
    }

    function getWithdrawalParams(uint256 shares, address queue, Config calldata config)
        external
        view
        returns (WithdrawalParams memory r)
    {
        Vault vault = Vault(payable(IRedeemQueue(queue).vault()));

        r = WithdrawalParams({
            isWithdrawalPossible: !vault.isPausedQueue(queue),
            asset: IRedeemQueue(queue).asset(),
            expectedLpAmount: shares,
            expectedLpAmountUSDC: 0,
            expectedAmount: 0,
            expectedAmountUSDC: 0,
            eta: 0
        });
        if (!r.isWithdrawalPossible) {
            return r;
        }
        IOracle vaultOracle = vault.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(r.asset);
        if (report.isSuspicious || report.timestmap == 0) {
            return r;
        }

        r.expectedAmount = Math.mulDiv(r.expectedLpAmount, 1 ether, report.priceD18);
        r.expectedAmountUSDC = oracle.getValue(r.asset, USD, r.expectedAmount);
        r.expectedLpAmountUSDC = r.expectedAmountUSDC;

        IFeeManager feeManager = vault.feeManager();
        if (feeManager.redeemFeeD6() != 0) {
            r.expectedAmount -= feeManager.calculateRedeemFee(r.expectedAmount);
            r.expectedAmountUSDC -= feeManager.calculateRedeemFee(r.expectedAmountUSDC);
        }

        r.eta = _findNextTimestamp(
            report.timestamp, block.timestamp, vaultOracle.securityParams().redeemInterval, config.oracleUpdateInterval
        );
    }
}
