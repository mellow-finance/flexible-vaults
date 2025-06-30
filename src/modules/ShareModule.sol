// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IShareModule.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";

/*
    TODO: add sunset functionality for queues
*/
abstract contract ShareModule is IShareModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SET_CUSTOM_HOOK_ROLE = keccak256("modules.ShareModule.SET_CUSTOM_HOOK_ROLE");
    bytes32 public constant CREATE_DEPOSIT_QUEUE_ROLE = keccak256("modules.ShareModule.CREATE_DEPOSIT_QUEUE_ROLE");
    bytes32 public constant CREATE_REDEEM_QUEUE_ROLE = keccak256("modules.ShareModule.CREATE_REDEEM_QUEUE_ROLE");

    bytes32 private immutable _shareModuleStorageSlot;

    IFactory public immutable override depositQueueFactory;
    IFactory public immutable override redeemQueueFactory;

    constructor(string memory name_, uint256 version_, address depositQueueFactory_, address redeemQueueFactory_) {
        _shareModuleStorageSlot = SlotLibrary.getSlot("ShareModule", name_, version_);
        depositQueueFactory = IFactory(depositQueueFactory_);
        redeemQueueFactory = IFactory(redeemQueueFactory_);
    }

    // View functions

    function shareManager() public view returns (IShareManager) {
        return IShareManager(_shareModuleStorage().shareManager);
    }

    function feeManager() public view returns (IFeeManager) {
        return IFeeManager(_shareModuleStorage().feeManager);
    }

    function oracle() public view returns (IOracle) {
        return IOracle(_shareModuleStorage().oracle);
    }

    function hasQueue(address queue) public view returns (bool) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        return $.queues[IQueue(queue).asset()].contains(queue);
    }

    function getAssetCount() public view returns (uint256) {
        return _shareModuleStorage().assets.length();
    }

    function assetAt(uint256 index) public view returns (address) {
        return _shareModuleStorage().assets.at(index);
    }

    function hasAsset(address asset) public view returns (bool) {
        return _shareModuleStorage().assets.contains(asset);
    }

    function queueAt(address asset, uint256 index) public view returns (address) {
        return _shareModuleStorage().queues[asset].at(index);
    }

    function getQueueCount(address asset) public view returns (uint256) {
        return _shareModuleStorage().queues[asset].length();
    }

    function isDepositQueue(address queue) public view returns (bool) {
        return _shareModuleStorage().isDepositQueue[queue];
    }

    function defaultDepositHook() public view returns (address) {
        return _shareModuleStorage().defaultDepositHook;
    }

    function defaultRedeemHook() public view returns (address) {
        return _shareModuleStorage().defaultRedeemHook;
    }

    /// @dev TODO: add onchain cheks to prevent OOG
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

    function getHook(address queue) public view returns (address hook) {
        ShareModuleStorage storage $ = _shareModuleStorage();
        hook = $.customHooks[queue];
        if (hook == address(0)) {
            hook = $.isDepositQueue[queue] ? $.defaultDepositHook : $.defaultRedeemHook;
        }
        return hook;
    }

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
    }

    function callHook(uint256 assets) external {
        address queue = _msgSender();
        ShareModuleStorage storage $ = _shareModuleStorage();
        address asset = IQueue(queue).asset();
        if (!_shareModuleStorage().queues[asset].contains(queue)) {
            revert Forbidden();
        }
        address hook = getHook(queue);
        if ($.isDepositQueue[queue]) {
            Address.functionDelegateCall(hook, abi.encodeCall(IDepositHook.afterDeposit, (asset, assets)));
        } else {
            Address.functionDelegateCall(hook, abi.encodeCall(IRedeemHook.beforeRedeem, (asset, assets)));
            TransferLibrary.sendAssets(asset, queue, assets);
        }
    }

    function setCustomHook(address queue, address hook) external onlyRole(SET_CUSTOM_HOOK_ROLE) {
        if (queue == address(0) || hook == address(0)) {
            revert ZeroAddress();
        }
        _shareModuleStorage().customHooks[queue] = hook;
    }

    function createDepositQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(CREATE_DEPOSIT_QUEUE_ROLE)
    {
        if (!IOracle(oracle()).isSupportedAsset(asset)) {
            revert UnsupportedAsset(asset);
        }
        requireFundamentalRole(FundamentalRole.PROXY_OWNER, owner);
        address queue = IFactory(depositQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        ShareModuleStorage storage $ = _shareModuleStorage();
        $.queues[asset].add(queue);
        $.isDepositQueue[queue] = true;
        $.assets.add(asset);
    }

    function createRedeemQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(CREATE_REDEEM_QUEUE_ROLE)
    {
        if (!IOracle(oracle()).isSupportedAsset(asset)) {
            revert UnsupportedAsset(asset);
        }
        requireFundamentalRole(FundamentalRole.PROXY_OWNER, owner);
        address queue = IFactory(redeemQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        ShareModuleStorage storage $ = _shareModuleStorage();
        $.queues[asset].add(queue);
        $.isDepositQueue[queue] = false;
        $.assets.add(asset);
    }

    function handleReport(address asset, uint224 priceD18, uint32 latestEligibleTimestamp) external {
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
    }

    // Internal functions

    function __ShareModule_init(
        address shareManager_,
        address feeManager_,
        address oracle_,
        address defaultDepositHook_,
        address defaultRedeemHook_
    ) internal onlyInitializing {
        if (
            shareManager_ == address(0) || feeManager_ == address(0) || oracle_ == address(0)
                || defaultDepositHook_ == address(0) || defaultRedeemHook_ == address(0)
        ) {
            revert ZeroAddress();
        }
        ShareModuleStorage storage $ = _shareModuleStorage();
        $.shareManager = shareManager_;
        $.feeManager = feeManager_;
        $.oracle = oracle_;
        $.defaultDepositHook = defaultDepositHook_;
        $.defaultRedeemHook = defaultRedeemHook_;
        $.queueLimit = 16;
    }

    function _shareModuleStorage() internal view returns (ShareModuleStorage storage $) {
        bytes32 slot = _shareModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
