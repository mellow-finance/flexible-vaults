// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

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

    /// @inheritdoc IDepositQueue
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

    /// @inheritdoc IDepositQueue
    function requestOf(address account) public view returns (uint256 timestamp, uint256 assets) {
        Checkpoints.Checkpoint224 memory request = _depositQueueStorage().requestOf[account];
        return (request._key, request._value);
    }

    /// @inheritdoc IQueue
    function canBeRemoved() external view returns (bool) {
        return _depositQueueStorage().handledIndices == _timestamps().length();
    }

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_,) = abi.decode(data, (address, address, bytes));
        __Queue_init(asset_, shareModule_);
        _depositQueueStorage().requests.initialize(16);
        emit Initialized(data);
    }

    /// @inheritdoc IDepositQueue
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (assets == 0) {
            revert ZeroValue();
        }
        address caller = _msgSender();
        DepositQueueStorage storage $ = _depositQueueStorage();
        address vault_ = vault();
        if (IShareModule(vault_).isPausedQueue(address(this))) {
            revert QueuePaused();
        }
        if (!IShareModule(vault_).shareManager().isDepositorWhitelisted(caller, merkleProof)) {
            revert DepositNotAllowed();
        }
        if ($.requestOf[caller]._value != 0 && !_claim(caller)) {
            revert PendingRequestExists();
        }

        address asset_ = asset();
        TransferLibrary.receiveAssets(asset_, caller, assets);
        uint32 timestamp = uint32(block.timestamp);
        Checkpoints.Trace224 storage timestamps = _timestamps();
        uint256 index = timestamps.length();
        (, uint32 latestTimestamp,) = timestamps.latestCheckpoint();
        if (latestTimestamp < timestamp) {
            timestamps.push(timestamp, uint224(index));
            if ($.requests.length() == index) {
                $.requests.extend();
            }
        } else {
            --index;
        }

        IVaultModule(vault_).riskManager().modifyPendingAssets(asset_, int256(uint256(assets)));
        $.requests.modify(index, int256(uint256(assets)));
        $.requestOf[caller] = Checkpoints.Checkpoint224(timestamp, assets);
        emit DepositRequested(caller, referral, assets, timestamp);
    }

    /// @inheritdoc IDepositQueue
    function cancelDepositRequest() external nonReentrant {
        address caller = _msgSender();
        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Checkpoint224 memory request = $.requestOf[caller];
        uint256 assets = request._value;
        if (assets == 0) {
            revert NoPendingRequest();
        }
        address asset_ = asset();
        (bool exists, uint32 timestamp, uint256 index) = $.prices.latestCheckpoint();
        if (exists && timestamp >= request._key) {
            revert ClaimableRequestExists();
        }

        delete $.requestOf[caller];
        IVaultModule(vault()).riskManager().modifyPendingAssets(asset_, -int256(uint256(assets)));
        $.requests.modify(index, -int256(assets));
        TransferLibrary.sendAssets(asset_, caller, assets);
        emit DepositRequestCanceled(caller, assets, request._key);
    }

    /// @inheritdoc IDepositQueue
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
            IShareModule(vault()).shareManager().mintAllocatedShares(account, shares);
        }
        emit DepositRequestClaimed(account, shares, request._key);
        return true;
    }

    function _handleReport(uint224 priceD18, uint32 timestamp) internal override {
        IShareModule vault_ = IShareModule(vault());

        DepositQueueStorage storage $ = _depositQueueStorage();
        Checkpoints.Trace224 storage timestamps = _timestamps();
        uint256 latestEligibleIndex;
        {
            (, uint32 latestTimestamp, uint224 latestIndex) = timestamps.latestCheckpoint();
            if (latestTimestamp <= timestamp) {
                latestEligibleIndex = latestIndex;
            } else {
                latestEligibleIndex = uint256(timestamps.upperLookupRecent(timestamp));
                if (latestEligibleIndex == 0) {
                    return;
                }
                latestEligibleIndex--;
            }

            if (latestEligibleIndex < $.handledIndices) {
                return;
            }
        }
        uint256 assets = uint256($.requests.get($.handledIndices, latestEligibleIndex));
        $.handledIndices = latestEligibleIndex + 1;

        IFeeManager feeManager = vault_.feeManager();
        uint224 feePriceD18 = uint224(feeManager.calculateDepositFee(priceD18));
        uint224 reducedPriceD18 = priceD18 - feePriceD18;
        $.prices.push(timestamp, reducedPriceD18);

        if (assets == 0) {
            return;
        }

        {
            IShareManager shareManager_ = vault_.shareManager();
            uint256 shares = Math.mulDiv(assets, reducedPriceD18, 1 ether);
            if (shares > 0) {
                shareManager_.allocateShares(shares);
            }
            uint256 fees = Math.mulDiv(assets, priceD18, 1 ether) - shares;
            if (fees > 0) {
                shareManager_.mint(feeManager.feeRecipient(), fees);
            }
        }

        address asset_ = asset();
        TransferLibrary.sendAssets(asset_, address(vault_), assets);
        IRiskManager riskManager = IVaultModule(address(vault_)).riskManager();
        riskManager.modifyPendingAssets(asset_, -int256(uint256(assets)));
        riskManager.modifyVaultBalance(asset_, int256(uint256(assets)));
        vault_.callHook(assets);
    }

    function _depositQueueStorage() internal view returns (DepositQueueStorage storage dqs) {
        bytes32 slot = _depositQueueStorageSlot;
        assembly {
            dqs.slot := slot
        }
    }
}
