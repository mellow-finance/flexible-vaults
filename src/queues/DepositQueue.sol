// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ISharesModule.sol";
import "../interfaces/queues/IDepositQueue.sol";

import "../libraries/FenwickTreeLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./Queue.sol";

contract DepositQueue is IDepositQueue, Queue {
    using FenwickTreeLibrary for FenwickTreeLibrary.Tree;
    using Checkpoints for Checkpoints.Trace224;

    bytes32 private immutable _depositQueueStorageSlot;

    constructor(string memory name_, uint256 version_) Queue(name_, version_) {
        _depositQueueStorageSlot = SlotLibrary.getSlot("DepositQueue", name_, version_);
    }

    // View functions

    function claimableOf(address account) public view returns (uint256) {
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint224 memory request = $.requestOf[account];
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
        Checkpoints.Checkpoint224 memory request = _depositQueueStorage().requestOf[account];
        return (request._key, request._value);
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        __ReentrancyGuard_init();
        (address asset_, address sharesModule_,) = abi.decode(data, (address, address, bytes));
        __Queue_init(asset_, sharesModule_);
        _depositQueueStorage().requests.initialize(16);
    }

    /*
        TODO: add refcode
    */
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (assets == 0) {
            revert("DepositQueue: zero assets");
        }
        address caller = _msgSender();
        if (!ISharesManager(sharesManager()).isDepositorWhitelisted(caller, merkleProof)) {
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
        uint32 timestamp = uint32(block.timestamp);
        uint256 index;
        Checkpoints.Trace224 storage timestamps = _timestamps();
        (, uint32 latestTimestamp,) = timestamps.latestCheckpoint();
        if (latestTimestamp < timestamp) {
            index = timestamps.length();
            timestamps.push(timestamp, uint224(index));
            if ($.requests.length() == index) {
                $.requests.extend();
            }
        } else {
            index = timestamps.length() - 1;
        }

        IRootVaultModule(vault()).riskManager().modifyPendingAssets(asset_, int256(uint256(assets)));
        $.requests.modify(index, int256(uint256(assets)));
        $.requestOf[caller] = Checkpoints.Checkpoint224(timestamp, assets);
        emit DepositRequested(caller, referral, assets, timestamp);
    }

    function cancelDepositRequest() external nonReentrant {
        address caller = _msgSender();
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint224 memory request = $.requestOf[caller];
        uint256 assets = request._value;
        if (assets == 0) {
            revert("DepositQueue: no pending request");
        }
        address asset_ = asset();
        (bool exists, uint32 timestamp,) = $.prices.latestCheckpoint();
        if (exists && timestamp >= request._key) {
            revert("DepositQueue: request already processed");
        }

        delete $.requestOf[caller];
        TransferLibrary.sendAssets(asset_, caller, assets);
        IRootVaultModule(vault()).riskManager().modifyPendingAssets(asset_, -int256(uint256(assets)));
    }

    function claim(address account) external returns (bool) {
        return _claim(account);
    }

    // Internal functions

    function _claim(address account) internal returns (bool) {
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint224 memory request = $.requestOf[account];
        uint256 priceD18 = $.prices.lowerLookup(request._key);
        if (priceD18 == 0) {
            return false;
        }
        uint256 shares = Math.mulDiv(request._value, priceD18, 1 ether);
        delete $.requestOf[account];
        if (shares != 0) {
            ISharesManager(sharesManager()).mintAllocatedShares(account, shares);
        }
        return true;
    }

    function _handleReport(uint224 priceD18, uint32 latestEligibleTimestamp) internal override {
        IDepositModule vault_ = IDepositModule(vault());
        address asset_ = asset();

        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Trace224 storage timestamps = _timestamps();
        (bool exists, uint32 latestTimestamp, uint224 latestIndex) = timestamps.latestCheckpoint();
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
        IRootVaultModule(address(vault_)).riskManager().modifyVaultBalance(asset_, int256(uint256(assets)));
        address hook = vault_.getDepositHook(asset_);
        if (hook != address(0)) {
            IDepositHook(hook).afterDeposit(address(vault_), asset_, assets);
        }

        uint256 shares = Math.mulDiv(assets, priceD18, 1 ether);
        if (shares > 0) {
            ISharesManager(sharesManager()).allocateShares(shares);
        }
    }

    function _depositQueueStorage() internal view returns (DepositQueueStorage storage dqs) {
        bytes32 slot = _depositQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }

    event DepositRequested(address indexed account, address indexed referral, uint224 assets, uint32 timestamp);
}
