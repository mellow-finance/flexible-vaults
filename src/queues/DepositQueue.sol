// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import "../libraries/FenwickTreeLibrary.sol";
import "../libraries/TransferLibrary.sol";
import "../modules/DepositModule.sol";
import "./Queue.sol";

contract DepositQueue is Queue, ReentrancyGuardUpgradeable {
    using FenwickTreeLibrary for FenwickTreeLibrary.Tree;
    using Checkpoints for Checkpoints.Trace208;

    struct DepositQueueStorage {
        uint256 handledIndices;
        mapping(address account => Checkpoints.Checkpoint208) requestOf;
        FenwickTreeLibrary.Tree requests;
        Checkpoints.Trace208 prices;
    }

    bytes32 private immutable _depositQueueStorageSlot;

    constructor(string memory name_, uint256 version_) Queue(name_, version_) {
        _depositQueueStorageSlot = SlotLibrary.getSlot("DepositQueue", name_, version_);
    }

    // View functions

    function claimableOf(address account) public view returns (uint256) {
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint208 memory request = $.requestOf[account];
        if (request._key == 0) {
            return 0;
        }
        uint256 priceD18 = $.prices.lowerLookup(request._key);
        if (priceD18 == 0) {
            return 0;
        }
        return Math.mulDiv(request._value, priceD18, 1 ether);
    }

    function requestOf(address account) public view returns (uint256 timestamp, uint256 assets) {
        Checkpoints.Checkpoint208 memory request = _depositQueueStorage().requestOf[account];
        return (request._key, request._value);
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        __ReentrancyGuard_init();
        (address asset_, address sharesModule_) = abi.decode(data, (address, address));
        __Queue_init(asset_, sharesModule_);
        _depositQueueStorage().requests.initialize(16);
    }

    function deposit(uint208 assets, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (assets == 0) {
            revert("DepositQueue: zero assets");
        }
        address caller = _msgSender();
        if (!sharesManager().isDepositAllowed(caller, merkleProof)) {
            revert("DepositQueue: deposit not allowed");
        }
        DepositQueueStorage storage $ = _depositQueueStorage();
        if ($.requestOf[caller]._value != 0) {
            if (!_claim(caller)) {
                revert("DepositQueue: pending request");
            }
        }

        address asset_ = asset();
        TransferLibrary.receiveAssets(asset_, caller, assets);
        uint256 timestamp = block.timestamp;
        uint256 index;
        Checkpoints.Trace208 storage timestamps = _timestamps();
        uint208 latestTimestamp = timestamps.latest();
        if (latestTimestamp < timestamp) {
            index = timestamps.length();
            timestamps.push(uint48(timestamp), uint208(index));
            if ($.requests.length() == index) {
                $.requests.extend();
            }
        } else {
            index = timestamps.length() - 1;
        }

        $.requests.modify(index, int256(uint256(assets)));
        $.requestOf[caller] = Checkpoints.Checkpoint208(uint48(timestamp), uint208(assets));
    }

    function cancelDepositRequest() external nonReentrant {
        address caller = _msgSender();
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint208 memory request = $.requestOf[caller];
        uint256 assets = request._value;
        if (assets == 0) {
            revert("DepositQueue: no pending request");
        }
        address asset_ = asset();
        (bool exists, uint48 timestamp,) = $.prices.latestCheckpoint();
        if (exists && timestamp >= request._key) {
            revert("DepositQueue: request already processed");
        }

        delete $.requestOf[caller];
        TransferLibrary.sendAssets(asset_, caller, assets);
    }

    function claim(address account) external nonReentrant returns (bool) {
        return _claim(account);
    }

    // Internal functions

    function _claim(address account) internal returns (bool) {
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint208 memory request = $.requestOf[account];
        uint256 priceD18 = $.prices.lowerLookup(request._key);
        if (priceD18 == 0) {
            return false;
        }
        uint256 shares = Math.mulDiv(request._value, priceD18, 1 ether);
        delete $.requestOf[account];
        if (shares != 0) {
            sharesManager().mintAllocatedShares(account, shares);
        }
        return true;
    }

    function _handleReport(uint208 priceD18, uint48 latestEligibleTimestamp) internal override {
        SharesModule vault_ = vault();
        address asset_ = asset();

        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Trace208 storage timestamps = _timestamps();
        (bool exists, uint48 latestTimestamp, uint208 latestIndex) = timestamps.latestCheckpoint();
        if (!exists) {
            return;
        }
        uint256 latestEligibleIndex;
        if (latestTimestamp <= latestEligibleTimestamp) {
            latestEligibleIndex = latestIndex;
        } else {
            latestEligibleIndex = uint256(timestamps.upperLookupRecent(latestEligibleTimestamp));
            if (latestEligibleIndex == 0) {
                return;
            }
            latestEligibleIndex--;
        }

        if (latestEligibleIndex < $.handledIndices) {
            return;
        }

        uint256 assets = uint256($.requests.get($.handledIndices, latestEligibleIndex));
        $.prices.push(latestEligibleTimestamp, priceD18);
        $.handledIndices = latestEligibleIndex + 1;

        if (assets == 0) {
            return;
        }

        TransferLibrary.sendAssets(asset_, address(vault_), assets);

        uint256 shares = Math.mulDiv(assets, priceD18, 1 ether);
        if (shares == 0) {
            return;
        }

        sharesManager().allocateShares(shares);
        DepositModule(payable(vault_)).callDepositHook(asset_, assets);
    }

    function _depositQueueStorage() internal view returns (DepositQueueStorage storage dqs) {
        bytes32 slot = _depositQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }
}
