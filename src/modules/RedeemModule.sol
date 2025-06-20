// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IRedeemModule.sol";
import "../libraries/PermissionsLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./ACLModule.sol";
import "./SharesModule.sol";

abstract contract RedeemModule is IRedeemModule, SharesModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _redeemModuleStorageSlot;
    address public immutable redeemQueueFactory;

    constructor(string memory name_, uint256 version_, address redeemQueueFactory_) {
        _redeemModuleStorageSlot = SlotLibrary.getSlot("RedeemModule", name_, version_);
        redeemQueueFactory = redeemQueueFactory_;
    }

    // View functions:

    function redeemAssets() public view returns (uint256) {
        return _redeemModuleStorage().assets.length();
    }

    function redeemAssetAt(uint256 index) public view returns (address) {
        return _redeemModuleStorage().assets.at(index);
    }

    function isRedeemAsset(address asset) public view returns (bool) {
        return _redeemModuleStorage().assets.contains(asset);
    }

    function hasRedeemQueue(address queue) public view returns (bool) {
        return _redeemModuleStorage().queues[IQueue(queue).asset()].contains(queue);
    }

    function redeemQueues(address asset) public view returns (uint256) {
        return _redeemModuleStorage().queues[asset].length();
    }

    function redeemQueueAt(address asset, uint256 index) public view returns (address) {
        return _redeemModuleStorage().queues[asset].at(index);
    }

    function getRedeemQueues(address asset) public view virtual override returns (address[] memory queues) {
        return _redeemModuleStorage().queues[asset].values();
    }

    function getRedeemHook(address queue) public view returns (address hook) {
        RedeemModuleStorage storage $ = _redeemModuleStorage();
        hook = $.customHooks[queue];
        if (hook == address(0)) {
            hook = $.defaultHook;
        }
        return hook;
    }

    function getLiquidAssets(address asset) public view returns (uint256) {
        address caller = _msgSender();
        if (!_redeemModuleStorage().queues[asset].contains(caller)) {
            revert("RedeemModule: caller is not a queue");
        }
        return IRedeemHook(getRedeemHook(caller)).getLiquidAssets(asset);
    }

    // Mutable functions

    function setCustomRedeemHook(address queue, address hook)
        external
        onlyRole(PermissionsLibrary.SET_REDEEM_HOOK_ROLE)
    {
        if (queue == address(0) || hook == address(0)) {
            revert("RedeemModule: zero address");
        }
        _redeemModuleStorage().customHooks[queue] = hook;
    }

    function callRedeemHook(address asset, uint256 assets) external {
        address caller = _msgSender();
        if (!_redeemModuleStorage().queues[asset].contains(caller)) {
            revert("RedeemModule: caller is not a queue");
        }
        IRedeemHook(getRedeemHook(caller)).beforeRedeem(asset, assets);
        TransferLibrary.sendAssets(asset, caller, assets);
    }

    function createRedeemQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(PermissionsLibrary.CREATE_REDEEM_QUEUE_ROLE)
    {
        if (asset == address(0) || !IOracle(redeemOracle()).isSupportedAsset(asset)) {
            revert("RedeemModule: unsupported asset");
        }
        requireFundamentalRole(owner, FundamentalRole.PROXY_OWNER);
        address queue = IFactory(redeemQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        _grantRole(PermissionsLibrary.MODIFY_VAULT_BALANCE_ROLE, queue);
        RedeemModuleStorage storage $ = _redeemModuleStorage();
        $.queues[asset].add(queue);
        $.assets.add(asset);
    }

    // Internal functions

    function __RedeemModule_init(bytes calldata initParams) internal onlyInitializing {
        address defaultHook_ = abi.decode(initParams, (address));
        RedeemModuleStorage storage $ = _redeemModuleStorage();
        if (defaultHook_ == address(0)) {
            revert("RedeemModule: zero default hook address");
        }
        $.defaultHook = defaultHook_;
    }

    function _redeemModuleStorage() internal view returns (RedeemModuleStorage storage $) {
        bytes32 slot = _redeemModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
