// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/DepositQueue.sol";
import "../queues/Queue.sol";

import "../hooks/RedirectionDepositHook.sol";
import "./PermissionsModule.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract DepositModule is PermissionsModule {
    using EnumerableMap for EnumerableMap.AddressToAddressMap;

    struct DepositModuleStorage {
        uint256 verisions;
        mapping(uint256 version => address implementation) implementations;
        mapping(uint256 index => address queue) depositQueues;
        address defaultDepositHook;
        mapping(address asset => address hook) hooks;
        mapping(address => uint256) minDeposit;
        mapping(address => uint256) maxDeposit;
    }

    bytes32 private immutable _depositModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _depositModuleStorageSlot = SlotLibrary.getSlot("DepositModule", name_, version_);
    }

    // View functions:

    function depositQueueImplementation(uint256 version) public view returns (address) {
        return _depositModuleStorage().implementations[version];
    }

    function depositQueueVersions() public view returns (uint256) {
        return _depositModuleStorage().verisions;
    }

    function maxDeposit(address asset) public view returns (uint256) {
        return _depositModuleStorage().maxDeposit[asset];
    }

    function minDeposit(address asset) public view returns (uint256) {
        return _depositModuleStorage().minDeposit[asset];
    }

    function defaultDepositHook() external view returns (address) {
        return _depositModuleStorage().defaultDepositHook;
    }

    function depositHook(address asset) external view returns (address) {
        DepositModuleStorage storage $ = _depositModuleStorage();
        address hook = $.hooks[asset];
        if (hook == address(0)) {
            hook = $.defaultDepositHook;
        }
        return hook;
    }

    function claimableSharesOf(address account) public view returns (uint256 shares) {
        // EnumerableMap.AddressToAddressMap storage queues = _depositModuleStorage().depositQueues;
        // uint256 n = queues.length();
        // for (uint256 i = 0; i < n; i++) {
        //     (, address queue) = queues.at(i);
        //     shares += DepositQueue(queue).claimableOf(account);
        // }
    }

    // Mutable functions

    function setMaxDeposit(address asset, uint256 amount) external onlyRole(PermissionsLibrary.SET_MIN_DEPOSIT_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().maxDeposit[asset] = amount;
    }

    function setMinDeposit(address asset, uint256 amount) external onlyRole(PermissionsLibrary.SET_MAX_DEPOSIT_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().minDeposit[asset] = amount;
    }

    function setDepositHook(address asset, address hook) external onlyRole(PermissionsLibrary.SET_DEPOSIT_HOOK_ROLE) {
        if (asset == address(0) || hook == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().hooks[asset] = hook;
    }

    function createDepositQueue(address asset) external onlyRole(PermissionsLibrary.CREATE_DEPOSIT_QUEUE_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        DepositModuleStorage storage $ = _depositModuleStorage();
        // if ($.depositQueues.contains(asset)) {
        //     revert("DepositModule: queue already exists");
        // }
        // address queue =
        //     // Clones.cloneDeterministic($.depositQueueImplementation, bytes32(bytes20(asset)));
        // DepositQueue(queue).initialize(asset, address(this));
        // $.depositQueues.set(asset, address(queue));
    }

    // Internal functions

    function _depositModuleStorage() internal view returns (DepositModuleStorage storage $) {
        bytes32 slot = _depositModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }

    function __DepositModule_init(address depositQueueImplementation_) internal onlyInitializing {
        if (depositQueueImplementation_ == address(0)) {
            revert("DepositModule: zero address");
        }
        DepositModuleStorage storage $ = _depositModuleStorage();
        // $.depositQueueImplementation = depositQueueImplementation_;
        // $.defaultDepositHook = address(new RedirectionDepositHook(address(this)));
    }
}
