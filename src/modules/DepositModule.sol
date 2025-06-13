// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../hooks/DepositHook.sol";
import "../queues/DepositQueue.sol";
import "../queues/Queue.sol";
import "./ACLModule.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract DepositModule is SharesModule, ACLModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct DepositModuleStorage {
        address defaultHook;
        mapping(address queue => address) customHooks;
        EnumerableSet.AddressSet assets;
        mapping(address asset => EnumerableSet.AddressSet) queues;
    }

    bytes32 private immutable _depositModuleStorageSlot;
    address public immutable depositQueueFactory;

    constructor(string memory name_, uint256 version_, address depositQueueFactory_) {
        _depositModuleStorageSlot = SlotLibrary.getSlot("DepositModule", name_, version_);
        depositQueueFactory = depositQueueFactory_;
    }

    // View functions:

    function getDepositQueues(address asset) public view override(SharesModule) returns (address[] memory queues) {
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
                shares += DepositQueue(queues.at(j)).claimableOf(account);
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

    function setCustomDepositHook(address queue, address hook)
        external
        onlyRole(PermissionsLibrary.SET_DEPOSIT_HOOK_ROLE)
    {
        if (queue == address(0) || hook == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().customHooks[queue] = hook;
    }

    function callDepositHook(address asset, uint256 assets) external {
        address caller = _msgSender();
        DepositModuleStorage storage $ = _depositModuleStorage();
        EnumerableSet.AddressSet storage queues = $.queues[asset];
        if (!queues.contains(caller)) {
            revert("DepositModule: caller is not a queue");
        }
        address hook = getDepositHook(caller);
        if (hook == address(0)) {
            revert("DepositModule: no hook set");
        }
        Address.functionDelegateCall(hook, abi.encodeCall(DepositHook.onDeposit, (asset, assets)));
    }

    function createDepositQueue(address asset, uint256 version, bytes32 salt)
        external
        onlyRole(PermissionsLibrary.CREATE_DEPOSIT_QUEUE_ROLE)
    {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        DepositModuleStorage storage $ = _depositModuleStorage();
        address queue = Factory(DEPOSIT_QUEUE_FACTORY).create(version, owner, abi.encode(asset, address(this)), salt);
        $.queues.add(queue);
    }

    // Internal functions

    function __DepositModule_init(address beacon_, address defaultHook_) internal onlyInitializing {
        DepositModuleStorage storage $ = _depositModuleStorage();
        if (beacon_ == address(0) || defaultHook_ == address(0)) {
            revert("DepositModule: zero address");
        }
        // $.beacon = beacon_;
        $.defaultHook = defaultHook_;
    }

    function _depositModuleStorage() internal view returns (DepositModuleStorage storage $) {
        bytes32 slot = _depositModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
