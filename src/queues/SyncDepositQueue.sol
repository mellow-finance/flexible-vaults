// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISyncDepositQueue.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TransferLibrary.sol";

import "./SyncQueue.sol";

contract SyncDepositQueue is ISyncDepositQueue, SyncQueue {
    bytes32 private _syncDepositQueueStorageSlot;

    /// @inheritdoc ISyncDepositQueue
    bytes32 public constant SET_SYNC_DEPOSIT_PARAMS_ROLE =
        keccak256("queues.SyncDepositQueue.SET_SYNC_DEPOSIT_PARAMS_ROLE");

    constructor(string memory name_, uint256 version_) SyncQueue(name_, version_) {
        _syncDepositQueueStorageSlot = SlotLibrary.getSlot("SyncDepositQueue", name_, version_);
    }

    // View functions

    /// @inheritdoc ISyncQueue
    function name() external pure override returns (string memory) {
        return "SyncDepositQueue";
    }

    /// @inheritdoc ISyncDepositQueue
    function syncDepositParams() public view returns (uint256, uint32) {
        SyncDepositQueueStorage storage $ = _syncDepositQueueStorage();
        return ($.penaltyD6, $.maxAge);
    }

    /// @inheritdoc ISyncDepositQueue
    function claimableOf(address account) external pure returns (uint256 claimable) {}

    /// @inheritdoc ISyncDepositQueue
    function claim(address account) external pure returns (bool success) {}

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_, bytes memory data_) = abi.decode(data, (address, address, bytes));
        __SyncQueue_init(asset_, shareModule_);
        (uint256 penaltyD6, uint32 maxAge) = abi.decode(data_, (uint256, uint32));
        _setSyncDepositParams(penaltyD6, maxAge);
        emit Initialized(data);
    }

    /// @inheritdoc ISyncDepositQueue
    function setSyncDepositParams(uint256 penatlyD6, uint32 maxAge) external {
        if (!IAccessControl(vault()).hasRole(SET_SYNC_DEPOSIT_PARAMS_ROLE, _msgSender())) {
            revert Forbidden();
        }
        _setSyncDepositParams(penatlyD6, maxAge);
    }

    /// @inheritdoc ISyncDepositQueue
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (assets == 0) {
            revert ZeroValue();
        }
        address caller = _msgSender();
        IShareModule vault_ = IShareModule(vault());
        if (vault_.isPausedQueue(address(this))) {
            revert QueuePaused();
        }
        if (!vault_.shareManager().isDepositorWhitelisted(caller, merkleProof)) {
            revert DepositNotAllowed();
        }

        address asset_ = asset();
        uint256 priceD18;
        {
            (uint256 penaltyD6, uint32 maxAge) = syncDepositParams();
            IOracle oracle = IOracle(vault_.oracle());
            IOracle.DetailedReport memory report = oracle.getReport(asset_);
            if (report.isSuspicious || report.priceD18 == 0) {
                revert InvalidReport();
            }
            if (report.timestamp + maxAge < block.timestamp) {
                revert StaleReport();
            }
            priceD18 = Math.mulDiv(report.priceD18, 1e6 - penaltyD6, 1e6);
        }

        TransferLibrary.receiveAssets(asset_, caller, assets);
        TransferLibrary.sendAssets(asset_, address(vault_), assets);

        IFeeManager feeManager = vault_.feeManager();
        IShareManager shareManager_ = vault_.shareManager();
        uint256 shares = Math.mulDiv(assets, priceD18, 1 ether);
        uint256 feeShares = feeManager.calculateDepositFee(shares);
        if (feeShares > 0) {
            shareManager_.mint(feeManager.feeRecipient(), feeShares);
            shares -= feeShares;
        }
        if (shares > 0) {
            shareManager_.mint(caller, shares);
        } else {
            revert ZeroValue();
        }

        IRiskManager riskManager = IVaultModule(address(vault_)).riskManager();
        riskManager.modifyVaultBalance(asset_, int256(uint256(assets)));
        vault_.callHook(assets);

        emit Deposited(caller, referral, assets, shares, feeShares);
    }

    // Internal functions

    function _setSyncDepositParams(uint256 penaltyD6, uint32 maxAge) internal {
        if (penaltyD6 > 5e5 || maxAge > 365 days) {
            revert TooLarge();
        }
        if (maxAge == 0) {
            revert ZeroValue();
        }
        SyncDepositQueueStorage storage $ = _syncDepositQueueStorage();
        $.penaltyD6 = penaltyD6;
        $.maxAge = maxAge;
        emit SyncDepositParamsSet(penaltyD6, maxAge);
    }

    function _syncDepositQueueStorage() internal view returns (SyncDepositQueueStorage storage $) {
        bytes32 slot = _syncDepositQueueStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
