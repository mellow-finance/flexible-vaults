// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IDepositModule.sol";

import "./ACLModule.sol";
import "./ShareModule.sol";

import "../libraries/SlotLibrary.sol";

abstract contract DepositModule is IDepositModule, ShareModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private immutable _depositModuleStorageSlot;
    address public immutable depositQueueFactory;

    constructor(string memory name_, uint256 version_, address depositQueueFactory_) {
        _depositModuleStorageSlot = SlotLibrary.getSlot("DepositModule", name_, version_);
        depositQueueFactory = depositQueueFactory_;
    }

    // View functions

    function depositAssets() public view returns (uint256) {
        return _depositModuleStorage().assets.length();
    }

    function depositAssetAt(uint256 index) public view returns (address) {
        return _depositModuleStorage().assets.at(index);
    }

    function isDepositAsset(address asset) public view returns (bool) {
        return _depositModuleStorage().assets.contains(asset);
    }

    function hasDepositQueue(address queue) public view returns (bool) {
        return _depositModuleStorage().queues[IQueue(queue).asset()].contains(queue);
    }

    function depositQueues(address asset) public view returns (uint256) {
        return _depositModuleStorage().queues[asset].length();
    }

    function depositQueueAt(address asset, uint256 index) public view returns (address) {
        return _depositModuleStorage().queues[asset].at(index);
    }

    function getDepositQueues(address asset) public view virtual override returns (address[] memory queues) {
        return _depositModuleStorage().queues[asset].values();
    }

    function claimableSharesOf(address account) public view returns (uint256 shares) {
        DepositModuleStorage storage $ = _depositModuleStorage();
        EnumerableSet.AddressSet storage assets = $.assets;
        uint256 assetsCount = assets.length();
        for (uint256 i = 0; i < assetsCount; i++) {
            address asset = assets.at(i);
            EnumerableSet.AddressSet storage queues = $.queues[asset];
            uint256 queuesCount = queues.length();
            for (uint256 j = 0; j < queuesCount; j++) {
                shares += IDepositQueue(queues.at(j)).claimableOf(account);
            }
        }
        return shares;
    }

    function getDepositHook(address queue) public view returns (address hook) {
        DepositModuleStorage storage $ = _depositModuleStorage();
        hook = $.customHooks[queue];
        if (hook == address(0)) {
            hook = $.defaultHook;
        }
        return hook;
    }

    // Mutable functions

    function claimShares(address account) public {
        DepositModuleStorage storage $ = _depositModuleStorage();
        EnumerableSet.AddressSet storage assets = $.assets;
        uint256 assetsCount = assets.length();
        for (uint256 i = 0; i < assetsCount; i++) {
            address asset = assets.at(i);
            EnumerableSet.AddressSet storage queues = $.queues[asset];
            uint256 queuesCount = queues.length();
            for (uint256 j = 0; j < queuesCount; j++) {
                IDepositQueue(queues.at(j)).claim(account);
            }
        }
    }

    function setCustomDepositHook(address queue, address hook)
        external
        onlyRole(PermissionsLibrary.SET_DEPOSIT_HOOK_ROLE)
    {
        if (queue == address(0) || hook == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().customHooks[queue] = hook;
    }

    function createDepositQueue(uint256 version, address owner, address asset, bytes calldata data)
        external
        onlyRole(PermissionsLibrary.CREATE_DEPOSIT_QUEUE_ROLE)
    {
        if (asset == address(0) || !IOracle(depositOracle()).isSupportedAsset(asset)) {
            revert("DepositModule: unsupported asset");
        }
        requireFundamentalRole(owner, FundamentalRole.PROXY_OWNER);
        address queue = IFactory(depositQueueFactory).create(version, owner, abi.encode(asset, address(this), data));
        _grantRole(PermissionsLibrary.MODIFY_PENDING_ASSETS_ROLE, queue);
        _grantRole(PermissionsLibrary.MODIFY_VAULT_BALANCE_ROLE, queue);
        DepositModuleStorage storage $ = _depositModuleStorage();
        $.queues[asset].add(queue);
        $.assets.add(asset);
    }

    // Internal functions

    function __DepositModule_init(bytes calldata initParams) internal onlyInitializing {
        address defaultHook_ = abi.decode(initParams, (address));
        DepositModuleStorage storage $ = _depositModuleStorage();
        if (defaultHook_ == address(0)) {
            revert("DepositModule: zero address");
        }
        $.defaultHook = defaultHook_;
    }

    function _depositModuleStorage() internal view returns (DepositModuleStorage storage $) {
        bytes32 slot = _depositModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
