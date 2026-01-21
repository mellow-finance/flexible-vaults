// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../src/interfaces/managers/IFeeManager.sol";
import "../../src/interfaces/managers/IRiskManager.sol";
import "../../src/interfaces/managers/IShareManager.sol";
import "../../src/interfaces/oracles/IOracle.sol";

import "../../src/interfaces/queues/IDepositQueue.sol";
import "../../src/interfaces/queues/ISyncQueue.sol";

import "../../src/interfaces/queues/IRedeemQueue.sol";
import "../../src/interfaces/queues/ISignatureQueue.sol";

import "../../src/libraries/TransferLibrary.sol";
import "../../src/vaults/Vault.sol";

import "./oracles/IPriceOracle.sol";

contract Collector is OwnableUpgradeable {
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
        uint256 timestamp;
        uint256 eta;
    }

    struct QueueInfo {
        address queue;
        address asset;
        bool isDepositQueue;
        bool isPausedQueue;
        bool isSignatureQueue;
        uint256 pendingValue;
        uint256[] values;
    }

    struct Response {
        address vault;
        address baseAsset;
        address[] assets;
        uint8[] assetDecimals;
        uint256[] assetPrices;
        QueueInfo[] queues;
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
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IPriceOracle public oracle;
    uint256 public bufferSize;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address oracle_) external initializer {
        __Ownable_init(owner_);
        oracle = IPriceOracle(oracle_);
        bufferSize = 256;
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
                if (r.assets[i] == ETH) {
                    r.assetDecimals[i] = 18;
                } else {
                    r.assetDecimals[i] = IERC20Metadata(r.assets[i]).decimals();
                }
                r.assetPrices[i] = oracle.priceX96(r.assets[i]);
            }
        }

        r.totalLP = shareManager.totalShares();
        r.accountLP = shareManager.sharesOf(account);

        {
            r.totalBase = Math.mulDiv(r.totalLP, 1 ether, vault.oracle().getReport(r.baseAsset).priceD18);
            if (r.totalBase > 0) {
                r.totalUSD = oracle.getValue(r.baseAsset, USD, r.totalBase);
            }
        }

        {
            IRiskManager.State memory vaultState = riskManager.vaultState();
            int256 remainingLimit = vaultState.limit - vaultState.balance;
            if (remainingLimit < 0) {
                remainingLimit = 0;
            }
            r.limitLP = uint256(remainingLimit) + r.totalLP;

            r.deposits = _collectDeposits(vault, account, config);
            r.withdrawals = _collectWithdrawals(vault, account, config);
        }

        if (r.totalLP > 0) {
            r.accountBase = Math.mulDiv(r.accountLP, r.totalBase, r.totalLP);
            r.accountUSD = Math.mulDiv(r.accountLP, r.totalUSD, r.totalLP);
            r.limitBase = Math.mulDiv(r.limitLP, r.totalBase, r.totalLP);
            r.limitUSD = oracle.getValue(r.baseAsset, USD, r.limitBase);
            r.lpPriceBase = Math.mulDiv(r.totalBase, 1 ether, r.totalLP);
            r.lpPriceUSD = oracle.getValue(r.baseAsset, USD, r.lpPriceBase);
        }

        {
            r.queues = new QueueInfo[](vault.getQueueCount());
            uint256 iterator = 0;
            uint256 assetCount = vault.getAssetCount();
            for (uint256 i = 0; i < assetCount; i++) {
                address asset = vault.assetAt(i);
                uint256 queueCount = vault.getQueueCount(asset);
                for (uint256 j = 0; j < queueCount; j++) {
                    address queue = vault.queueAt(asset, j);
                    r.queues[iterator] = QueueInfo({
                        queue: queue,
                        asset: asset,
                        isDepositQueue: vault.isDepositQueue(queue),
                        isPausedQueue: vault.isPausedQueue(queue),
                        isSignatureQueue: false,
                        pendingValue: 0,
                        values: new uint256[](0)
                    });
                    if (isSignatureQueue(queue)) {
                        r.queues[iterator].isSignatureQueue = true;
                    } else if (r.queues[iterator].isDepositQueue) {
                        if (!isSyncDepositQueue(queue)) {
                            r.queues[iterator].pendingValue = TransferLibrary.balanceOf(asset, queue);
                        }
                    } else {
                        (r.queues[iterator].pendingValue, r.queues[iterator].values) = _collectRedeemQueueData(queue);
                    }
                    iterator++;
                }
            }
        }

        for (uint256 i = 0; i < r.queues.length; i++) {
            if (!r.queues[i].isDepositQueue) {
                continue;
            }
            address queue = r.queues[i].queue;
            address asset = r.queues[i].asset;
            uint256 pendingValue = TransferLibrary.balanceOf(asset, queue);
            if (pendingValue == 0) {
                continue;
            }
            if (asset != r.baseAsset) {
                r.totalBase += oracle.getValue(asset, r.baseAsset, pendingValue);
            } else {
                r.totalBase += pendingValue;
            }
        }
        if (r.totalBase > 0) {
            r.totalUSD = oracle.getValue(r.baseAsset, USD, r.totalBase);
        }
    }

    function _collectRedeemQueueData(address queue)
        internal
        view
        returns (uint256 pendingValue, uint256[] memory values)
    {
        uint256 limit;
        uint256 offset;
        (offset, limit,, pendingValue) = IRedeemQueue(queue).getState();
        values = new uint256[](limit - offset);
        for (uint256 i = 0; i < values.length; i++) {
            (values[i],) = IRedeemQueue(queue).batchAt(offset + i);
        }
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
                if (isSignatureQueue(queue)) {
                    continue;
                }
                if (isSyncDepositQueue(queue)) {
                    continue;
                }
                (uint256 timestamp, uint256 assets) = IDepositQueue(queue).requestOf(account);
                if (assets == 0) {
                    continue;
                }
                requests[iterator] = Request({
                    queue: queue,
                    asset: asset,
                    shares: IDepositQueue(queue).claimableOf(account),
                    timestamp: timestamp,
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
                        timestamp: redeemRequests[k].timestamp,
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
        return Math.max(
            block.timestamp + 1 hours,
            latestOracleUpdate
                + Math.max(oracleUpdateInterval, delta * (oracleUpdateInterval - 1) / oracleUpdateInterval)
        );
    }

    function isSyncDepositQueue(address queue) public view returns (bool) {
        try ISyncQueue(queue).name() returns (string memory name_) {
            if (keccak256(abi.encodePacked(name_)) == keccak256(abi.encodePacked("SyncDepositQueue"))) {
                return true;
            }
        } catch {}
        return false;
    }

    function isSignatureQueue(address queue) public view returns (bool) {
        try ISignatureQueue(queue).consensus() {
            return true;
        } catch {}
        return false;
    }

    function collect(address user, address[] memory vaults, Config[] calldata configs)
        public
        view
        returns (Response[] memory responses)
    {
        responses = new Response[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            responses[i] = collect(user, Vault(payable(vaults[i])), configs[i]);
        }
    }

    function multiCollect(address[] calldata users, address[] calldata vaults, Config[] calldata configs)
        external
        view
        returns (Response[][] memory responses)
    {
        responses = new Response[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            responses[i] = collect(users[i], vaults, configs);
        }
    }

    function getDepositParams(address queue, uint256 assets, address account, Config calldata config)
        external
        view
        returns (DepositParams memory r)
    {
        IDepositQueue depositQueue = IDepositQueue(queue);
        address vault = depositQueue.vault();
        r.asset = depositQueue.asset();
        IShareModule shareModule = IShareModule(vault);
        if (shareModule.isPausedQueue(queue)) {
            return r;
        }
        IOracle vaultOracle = shareModule.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(r.asset);
        if (report.isSuspicious || report.timestamp == 0) {
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
        }

        r.assets = assets;
        r.assetsUSDC = oracle.getValue(r.asset, USD, r.assets);

        r.shares = Math.mulDiv(assets, report.priceD18, 1 ether);
        r.sharesUSDC = r.assetsUSDC;

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
            shares: shares,
            sharesUSDC: 0,
            assets: 0,
            assetsUSDC: 0,
            eta: 0
        });
        if (!r.isWithdrawalPossible) {
            return r;
        }
        IOracle vaultOracle = vault.oracle();
        IOracle.DetailedReport memory report = vaultOracle.getReport(r.asset);
        if (report.isSuspicious || report.timestamp == 0) {
            return r;
        }

        r.assets = Math.mulDiv(r.shares, 1 ether, report.priceD18);
        r.assetsUSDC = oracle.getValue(r.asset, USD, r.assets);
        r.sharesUSDC = r.assetsUSDC;

        IFeeManager feeManager = vault.feeManager();
        if (feeManager.redeemFeeD6() != 0) {
            r.assets -= feeManager.calculateRedeemFee(r.assets);
            r.assetsUSDC -= feeManager.calculateRedeemFee(r.assetsUSDC);
        }

        r.eta = _findNextTimestamp(
            report.timestamp, block.timestamp, vaultOracle.securityParams().redeemInterval, config.oracleUpdateInterval
        );
    }
}
