// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/RedeemQueue.sol";
import "./ACLPermissionsModule.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract RedeemModule is ACLPermissionsModule {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToAddressMap;

    struct RedeemModuleStorage {
        address redeemQueueImplementation;
        EnumerableMap.AddressToAddressMap redeemQueues;
        mapping(address asset => uint256 shares) minRedeem;
        mapping(address asset => uint256 shares) maxRedeem;
    }

    bytes32 private immutable _redeemModleStorageSlot;

    constructor(string memory name_, uint256 version_) {
        _redeemModleStorageSlot = SlotLibrary.getSlot("Redeem", name_, version_);
    }

    // View functions

    function redeemWithdrawalQueueImplementation() public view returns (address) {
        return _redeemModuleStorage().redeemQueueImplementation;
    }

    function minRedeem(address asset) public view returns (uint256) {
        return _redeemModuleStorage().minRedeem[asset];
    }

    function maxRedeem(address asset) public view returns (uint256) {
        return _redeemModuleStorage().maxRedeem[asset];
    }

    function getRedeemAsset(uint256 index) public view returns (address asset) {
        (asset,) = _redeemModuleStorage().redeemQueues.at(index);
    }

    function getRedeemQueue(address asset) public view returns (bool, address) {
        return _redeemModuleStorage().redeemQueues.tryGet(asset);
    }

    function getRedeemAssetsCount() public view returns (uint256) {
        return _redeemModuleStorage().redeemQueues.length();
    }

    // Mutable functions

    function setMinRedeem(address asset, uint256 shares) external onlyRole(PermissionsLibrary.SET_MIN_REDEEM_ROLE) {
        if (asset == address(0)) {
            revert("RedeemModule: zero address");
        }
        _redeemModuleStorage().minRedeem[asset] = shares;
    }

    function setMaxRedeem(address asset, uint256 shares) external onlyRole(PermissionsLibrary.SET_MAX_REDEEM_ROLE) {
        if (asset == address(0)) {
            revert("RedeemModule: zero address");
        }
        _redeemModuleStorage().maxRedeem[asset] = shares;
    }

    function pull(address asset, uint256 assets) external {
        address caller = _msgSender();
        require(caller == _redeemModuleStorage().redeemQueues.get(asset), "RedeemModule: forbidden");
        TransferLibrary.sendAssets(asset, caller, assets);
    }

    function createWithdrawalQueue(address asset) external {
        if (asset == address(0)) {
            revert("RedeemModule: zero address");
        }
        RedeemModuleStorage storage $ = _redeemModuleStorage();
        if ($.redeemQueues.contains(asset)) {
            revert("RedeemModule: queue already exists");
        }
        address queue = Clones.cloneDeterministic($.redeemQueueImplementation, bytes32(bytes20(asset)));
        RedeemQueue(payable(queue)).initialize(asset, address(this));
        $.redeemQueues.set(asset, queue);
    }

    // Internal functions

    function _redeemModuleStorage() internal view returns (RedeemModuleStorage storage $) {
        bytes32 slot = _redeemModleStorageSlot;
        assembly {
            $.slot := slot
        }
    }

    function __RedeemModule_init(address redeemQueueImplementation_) internal onlyInitializing {
        if (redeemQueueImplementation_ == address(0)) {
            revert("RedeemModule: zero redeem queue implementation address");
        }
        _redeemModuleStorage().redeemQueueImplementation = redeemQueueImplementation_;
    }
}
