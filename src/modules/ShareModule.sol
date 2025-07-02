// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IShareModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

abstract contract ShareModule is IShareModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IShareModule
    bytes32 public constant SET_HOOK_ROLE = keccak256("modules.ShareModule.SET_HOOK_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant CREATE_DEPOSIT_QUEUE_ROLE = keccak256("modules.ShareModule.CREATE_DEPOSIT_QUEUE_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant CREATE_REDEEM_QUEUE_ROLE = keccak256("modules.ShareModule.CREATE_REDEEM_QUEUE_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant PAUSE_QUEUE_ROLE = keccak256("modules.ShareModule.PAUSE_QUEUE_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant UNPAUSE_QUEUE_ROLE = keccak256("modules.ShareModule.UNPAUSE_QUEUE_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant SET_QUEUE_LIMIT_ROLE = keccak256("modules.ShareModule.SET_QUEUE_LIMIT_ROLE");
    /// @inheritdoc IShareModule
    bytes32 public constant REMOVE_QUEUE_ROLE = keccak256("modules.ShareModule.REMOVE_QUEUE_ROLE");

    /// @inheritdoc IShareModule
    IFactory public immutable depositQueueFactory;
    /// @inheritdoc IShareModule
    IFactory public immutable redeemQueueFactory;

    bytes32 private immutable _shareModuleStorageSlot;

    constructor(string memory name_, uint256 version_, address depositQueueFactory_, address redeemQueueFactory_) {
        _shareModuleStorageSlot = SlotLibrary.getSlot("ShareModule", name_, version_);
        depositQueueFactory = IFactory(depositQueueFactory_);
        redeemQueueFactory = IFactory(redeemQueueFactory_);
    }

    // View functions

    /// @inheritdoc IShareModule
    function shareManager() public view returns (IShareManager) {
        return IShareManager(_shareModuleStorage().shareManager);
    }

    /// @inheritdoc IShareModule
    function feeManager() public view returns (IFeeManager) {
        return IFeeManager(_shareModuleStorage().feeManager);
    }

    /// @inheritdoc IShareModule
    function oracle() public view returns (IOracle) {
        return IOracle(_shareModuleStorage().oracle);
    }

    /// @inheritdoc IShareModule
    function hasQueue(address queue) public view returns (bool) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        return $.queues[IQueue(queue).asset()].contains(queue);
    }

    /// @inheritdoc IShareModule
    function getAssetCount() public view returns (uint256) {
        return _shareModuleStorage().assets.length();
    }

    /// @inheritdoc IShareModule
    function assetAt(uint256 index) public view returns (address) {
        return _shareModuleStorage().assets.at(index);
    }

    /// @inheritdoc IShareModule
    function hasAsset(address asset) public view returns (bool) {
        return _shareModuleStorage().assets.contains(asset);
    }

    /// @inheritdoc IShareModule
    function queueAt(address asset, uint256 index) public view returns (address) {
        return _shareModuleStorage().queues[asset].at(index);
    }

    /// @inheritdoc IShareModule
    function getQueueCount(address asset) public view returns (uint256) {
        return _shareModuleStorage().queues[asset].length();
    }

    /// @inheritdoc IShareModule
    function isDepositQueue(address queue) public view returns (bool) {
        return _shareModuleStorage().isDepositQueue[queue];
    }

    /// @inheritdoc IShareModule
    function isPausedQueue(address queue) public view returns (bool) {
        return _shareModuleStorage().isPausedQueue[queue];
    }

    /// @inheritdoc IShareModule
    function queueLimit() public view returns (uint256) {
        return _shareModuleStorage().queueLimit;
    }

    /// @inheritdoc IShareModule
    function getQueueCount() public view returns (uint256) {
        return _shareModuleStorage().queueCount;
    }

    /// @inheritdoc IShareModule
    function defaultDepositHook() public view returns (address) {
        return _shareModuleStorage().defaultDepositHook;
    }

    /// @inheritdoc IShareModule
    function defaultRedeemHook() public view returns (address) {
        return _shareModuleStorage().defaultRedeemHook;
    }

    /// @inheritdoc IShareModule
    function claimableSharesOf(address account) public view returns (uint256 shares) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        EnumerableSet.AddressSet storage assets = $.assets;
        uint256 assetsCount = assets.length();
        for (uint256 i = 0; i < assetsCount; i++) {
            address asset = assets.at(i);
            EnumerableSet.AddressSet storage queues = $.queues[asset];
            uint256 queuesCount = queues.length();
            for (uint256 j = 0; j < queuesCount; j++) {
                address queue = queues.at(j);
                if ($.isDepositQueue[queue]) {
                    shares += IDepositQueue(queue).claimableOf(account);
                }
            }
        }
        return shares;
    }

    /// @inheritdoc IShareModule
    function getHook(address queue) public view returns (address hook) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        hook = $.customHooks[queue];
        if (hook == address(0)) {
            hook = $.isDepositQueue[queue] ? $.defaultDepositHook : $.defaultRedeemHook;
        }
        return hook;
    }

    /// @inheritdoc IShareModule
    function getLiquidAssets() public view returns (uint256) {
        address queue = _msgSender();
        ShareModuleStorage storage $ = _shareModuleStorage();
        address asset = IQueue(queue).asset();
        if (!$.queues[asset].contains(queue) || $.isDepositQueue[queue]) {
            revert Forbidden();
        }
        return IRedeemHook(getHook(queue)).getLiquidAssets(asset);
    }

    // Mutable functions

    /// @inheritdoc IShareModule
    function claimShares(address account) public {
        ShareModuleStorage storage $ = _shareModuleStorage();
        EnumerableSet.AddressSet storage assets = $.assets;
        uint256 assetsCount = assets.length();
        for (uint256 i = 0; i < assetsCount; i++) {
            address asset = assets.at(i);
            EnumerableSet.AddressSet storage queues = $.queues[asset];
            uint256 queuesCount = queues.length();
            for (uint256 j = 0; j < queuesCount; j++) {
                address queue = queues.at(j);
                if ($.isDepositQueue[queue]) {
                    IDepositQueue(queue).claim(account);
                }
            }
        }
        emit SharesClaimed(account);
    }

    /// @inheritdoc IShareModule
    function callHook(uint256 assets) external {
        address queue = _msgSender();
        ShareModuleStorage storage $ = _shareModuleStorage();
        address asset = IQueue(queue).asset();
        if (!_shareModuleStorage().queues[asset].contains(queue)) {
            revert Forbidden();
        }
        address hook = getHook(queue);
        if ($.isDepositQueue[queue]) {
            if (hook != address(0)) {
                Address.functionDelegateCall(hook, abi.encodeCall(IDepositHook.afterDeposit, (asset, assets)));
            }
        } else {
            if (hook != address(0)) {
                Address.functionDelegateCall(hook, abi.encodeCall(IRedeemHook.beforeRedeem, (asset, assets)));
            }
            TransferLibrary.sendAssets(asset, queue, assets);
        }
        emit HookCalled(queue, asset, assets, hook);
    }

    /// @inheritdoc IShareModule
    function setCustomHook(address queue, address hook) external onlyRole(SET_HOOK_ROLE) {
        if (queue == address(0) || hook == address(0)) {
            revert ZeroAddress();
        }
        _shareModuleStorage().customHooks[queue] = hook;
        emit CustomHookSet(queue, hook);
    }

    /// @inheritdoc IShareModule
    function setDefaultDepositHook(address hook) external onlyRole(SET_HOOK_ROLE) {
        _shareModuleStorage().defaultDepositHook = hook;
        emit DefaultHookSet(hook, true);
    }

    /// @inheritdoc IShareModule
    function setDefaultRedeemHook(address hook) external onlyRole(SET_HOOK_ROLE) {
        _shareModuleStorage().defaultDepositHook = hook;
        emit DefaultHookSet(hook, false);
    }

    /// @inheritdoc IShareModule
    function createDepositQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(CREATE_DEPOSIT_QUEUE_ROLE)
    {
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (!IOracle($.oracle).isSupportedAsset(asset)) {
            revert UnsupportedAsset(asset);
        }
        if ($.queueCount == $.queueLimit) {
            revert QueueLimitReached();
        }
        requireFundamentalRole(FundamentalRole.PROXY_OWNER, owner);
        address queue = IFactory(depositQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        $.queueCount++;
        $.queues[asset].add(queue);
        $.isDepositQueue[queue] = true;
        $.assets.add(asset);
        emit QueueCreated(queue, asset, true);
    }

    /// @inheritdoc IShareModule
    function createRedeemQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(CREATE_REDEEM_QUEUE_ROLE)
    {
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (!IOracle($.oracle).isSupportedAsset(asset)) {
            revert UnsupportedAsset(asset);
        }
        if ($.queueCount == $.queueLimit) {
            revert QueueLimitReached();
        }
        requireFundamentalRole(FundamentalRole.PROXY_OWNER, owner);
        address queue = IFactory(redeemQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        $.queueCount++;
        $.queues[asset].add(queue);
        $.isDepositQueue[queue] = false;
        $.assets.add(asset);
        emit QueueCreated(queue, asset, false);
    }

    /// @inheritdoc IShareModule
    function removeQueue(address queue) external onlyRole(REMOVE_QUEUE_ROLE) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (!IQueue(queue).canBeRemoved()) {
            revert Forbidden();
        }
        address asset = IQueue(queue).asset();
        if (!$.queues[asset].contains(queue)) {
            revert Forbidden();
        }
        $.queues[asset].remove(queue);
        delete $.isDepositQueue[queue];
        if ($.queues[asset].length() == 0) {
            $.assets.remove(asset);
        }
        delete $.customHooks[queue];
        $.queueCount--;
        emit QueueRemoved(queue, asset);
    }

    /// @inheritdoc IShareModule
    function setQueueLimit(uint256 limit) external onlyRole(SET_QUEUE_LIMIT_ROLE) {
        _shareModuleStorage().queueLimit = limit;
        emit QueueLimitSet(limit);
    }

    /// @inheritdoc IShareModule
    function pauseQueue(address queue) external onlyRole(PAUSE_QUEUE_ROLE) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (!$.queues[IQueue(queue).asset()].contains(queue)) {
            revert Forbidden();
        }
        $.isPausedQueue[queue] = true;
        emit QueuePaused(queue);
    }

    /// @inheritdoc IShareModule
    function unpauseQueue(address queue) external onlyRole(UNPAUSE_QUEUE_ROLE) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (!$.queues[IQueue(queue).asset()].contains(queue)) {
            revert Forbidden();
        }
        $.isPausedQueue[queue] = false;
        emit QueueUnpaused(queue);
    }

    /// @inheritdoc IShareModule
    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external nonReentrant {
        address caller = _msgSender();
        ShareModuleStorage storage $ = _shareModuleStorage();
        if (caller != $.oracle) {
            revert Forbidden();
        }
        EnumerableSet.AddressSet storage queues = _shareModuleStorage().queues[asset];
        uint256 length = queues.length();
        for (uint256 i = 0; i < length; i++) {
            address queue = queues.at(i);
            if ($.isDepositQueue[queue]) {
                IQueue(queue).handleReport(priceD18, latestEligibleTimestamp);
            } else {
                IQueue(queue).handleReport(1e36 / priceD18, latestEligibleTimestamp);
            }
        }

        IFeeManager feeManager_ = feeManager();
        uint256 fees = feeManager_.calculateProtocolFee(address(this), shareManager().totalShares())
            + feeManager_.calculatePerformanceFee(address(this), asset, priceD18);
        if (fees > 0) {
            shareManager().mint(feeManager_.feeRecipient(), fees);
        }
        feeManager_.updateState(asset, priceD18);
        emit ReportHandled(asset, priceD18, latestEligibleTimestamp, fees);
    }

    // Internal functions

    function __ShareModule_init(
        address shareManager_,
        address feeManager_,
        address oracle_,
        address defaultDepositHook_,
        address defaultRedeemHook_
    ) internal onlyInitializing {
        if (shareManager_ == address(0) || feeManager_ == address(0) || oracle_ == address(0)) {
            revert ZeroAddress();
        }
        ShareModuleStorage storage $ = _shareModuleStorage();
        $.shareManager = shareManager_;
        $.feeManager = feeManager_;
        $.oracle = oracle_;
        $.defaultDepositHook = defaultDepositHook_;
        $.defaultRedeemHook = defaultRedeemHook_;
    }

    function _shareModuleStorage() internal view returns (ShareModuleStorage storage $) {
        bytes32 slot = _shareModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
