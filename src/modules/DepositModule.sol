// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/DepositQueue.sol";
import "../queues/Queue.sol";

import "../strategies/RedirectionDepositHook.sol";
import "./PermissionsModule.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract DepositModule is PermissionsModule {
    using EnumerableMap for EnumerableMap.AddressToAddressMap;

    struct DepositModuleStorage {
        address defaultDepositHook;
        address depositQueueImplementation;
        EnumerableMap.AddressToAddressMap depositQueues;
        mapping(address asset => address hook) hooks;
        mapping(address => uint256) minDeposit;
        mapping(address => uint256) maxDeposit;
    }

    bytes32 public constant SET_MIN_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MIN_DEPOSIT_ROLE");
    bytes32 public constant SET_MAX_DEPOSIT_ROLE = keccak256("DEPOSIT_MODULE:SET_MAX_DEPOSIT_ROLE");
    bytes32 public constant SET_DEPOSIT_HOOK_ROLE =
        keccak256("DEPOSIT_MODULE:SET_DEPOSIT_HOOK_ROLE");
    bytes32 public constant CREATE_DEPOSIT_QUEUE_ROLE =
        keccak256("DEPOSIT_MODULE:CREATE_DEPOSIT_QUEUE_ROLE");

    bytes32 private immutable _depositModuleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _depositModuleStorageSlot = SlotLibrary.getSlot("DepositModule", name_, version_);
    }

    // View functions:

    function depositQueueImplementation() public view returns (address) {
        return _depositModuleStorage().depositQueueImplementation;
    }

    function maxDeposit(address asset) public view returns (uint256) {
        return _depositModuleStorage().maxDeposit[asset];
    }

    function minDeposit(address asset) public view returns (uint256) {
        return _depositModuleStorage().minDeposit[asset];
    }

    function getDepositAsset(uint256 index) public view returns (address asset) {
        (asset,) = _depositModuleStorage().depositQueues.at(index);
    }

    function getDepositQueue(address asset) public view returns (bool, address) {
        return _depositModuleStorage().depositQueues.tryGet(asset);
    }

    function depositAssets() public view returns (uint256) {
        return _depositModuleStorage().depositQueues.length();
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
        EnumerableMap.AddressToAddressMap storage queues = _depositModuleStorage().depositQueues;
        uint256 n = queues.length();
        for (uint256 i = 0; i < n; i++) {
            (, address queue) = queues.at(i);
            shares += DepositQueue(queue).claimableOf(account);
        }
    }

    // Mutable functions

    function setMaxDeposit(address asset, uint256 amount) external onlyRole(SET_MIN_DEPOSIT_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().maxDeposit[asset] = amount;
    }

    function setMinDeposit(address asset, uint256 amount) external onlyRole(SET_MAX_DEPOSIT_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().minDeposit[asset] = amount;
    }

    function setDepositHook(address asset, address hook) external onlyRole(SET_DEPOSIT_HOOK_ROLE) {
        if (asset == address(0) || hook == address(0)) {
            revert("DepositModule: zero address");
        }
        _depositModuleStorage().hooks[asset] = hook;
    }

    function createDepositQueue(address asset) external onlyRole(CREATE_DEPOSIT_QUEUE_ROLE) {
        if (asset == address(0)) {
            revert("DepositModule: zero address");
        }
        DepositModuleStorage storage $ = _depositModuleStorage();
        if ($.depositQueues.contains(asset)) {
            revert("DepositModule: queue already exists");
        }
        address queue =
            Clones.cloneDeterministic($.depositQueueImplementation, bytes32(bytes20(asset)));
        DepositQueue(queue).initialize(asset, address(this));
        $.depositQueues.set(asset, address(queue));
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
        _depositModuleStorage().depositQueueImplementation = depositQueueImplementation_;
        _depositModuleStorage().defaultDepositHook = address(RedirectionDepositHook(address(this)));
    }
}
