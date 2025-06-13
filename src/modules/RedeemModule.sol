// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../queues/RedeemQueue.sol";
import "./ACLModule.sol";

import "../libraries/PermissionsLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract RedeemModule is SharesModule, ACLModule {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct RedeemModuleStorage {
        EnumerableSet.AddressSet queues;
        mapping(address queue => address) hooks;
    }

    bytes32 private immutable _redeemModleStorageSlot;
    address public immutable REDEEM_QUEUE_FACTORY;

    constructor(string memory name_, uint256 version_, address redeemQueueFactory_) {
        _redeemModleStorageSlot = SlotLibrary.getSlot("Redeem", name_, version_);
        REDEEM_QUEUE_FACTORY = redeemQueueFactory_;
    }

    // View functions

    function getRedeemQueues(address /* asset */ ) public view override returns (address[] memory) {}

    // Mutable functions

    function pullAssets(address asset, uint256 assets) external virtual {
        // TODO: add hooks
        // address caller = _msgSender();
        // require(caller == _redeemModuleStorage().redeemQueues.get(asset), "RedeemModule: forbidden");
        // TransferLibrary.sendAssets(asset, caller, assets);
    }

    function availablePullAssets(address asset) external view virtual returns (uint256) {
        // call the same hook

        // default implementation here
        return IERC20(asset).balanceOf(address(this));
    }

    function createRedeemQueue(address asset) external {
        // TODO: implement REDEEM_QUEUE_FACTORY
    }

    // Internal functions

    function _redeemModuleStorage() internal view returns (RedeemModuleStorage storage $) {
        bytes32 slot = _redeemModleStorageSlot;
        assembly {
            $.slot := slot
        }
    }

    function __RedeemModule_init(address redeemQueueImplementation_) internal onlyInitializing {
        // if (redeemQueueImplementation_ == address(0)) {
        //     revert("RedeemModule: zero redeem queue implementation address");
        // }
        // _redeemModuleStorage().redeemQueueImplementation = redeemQueueImplementation_;
    }
}
