// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISyncDepositQueue.sol";
import "../libraries/TransferLibrary.sol";

import "./SyncQueue.sol";

contract SyncDepositQueue is ISyncDepositQueue, SyncQueue {
    constructor(string memory name_, uint256 version_) SyncQueue(name_, version_) {}

    // View functions

    /// @inheritdoc ISyncQueue
    function name() external pure override returns (string memory) {
        return "SyncDepositQueue";
    }

    /// @inheritdoc ISyncDepositQueue
    function claimableOf(address account) external pure returns (uint256 claimable) {}

    /// @inheritdoc ISyncDepositQueue
    function claim(address account) external pure returns (bool success) {}

    // Mutable functions

    /// @inheritdoc IFactoryEntity
    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_,) = abi.decode(data, (address, address, bytes));
        __SyncQueue_init(asset_, shareModule_);

        emit Initialized(data);
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
        IOracle.DetailedReport memory report = IOracle(vault_.oracle()).getReport(asset_);
        if (report.isSuspicious || report.priceD18 == 0) {
            revert InvalidReport();
        }

        TransferLibrary.receiveAssets(asset_, caller, assets);
        TransferLibrary.sendAssets(asset_, address(vault_), assets);

        IFeeManager feeManager = vault_.feeManager();
        IShareManager shareManager_ = vault_.shareManager();
        /*
            TODO: replace `1 ether` with more complex logic with time-weighted coefficients (?)
        */
        uint256 shares = Math.mulDiv(assets, report.priceD18, 1 ether);
        uint256 feeShares = feeManager.calculateDepositFee(shares);
        if (feeShares > 0) {
            shareManager_.mint(feeManager.feeRecipient(), feeShares);
            shares -= feeShares;
        }
        if (shares > 0) {
            shareManager_.mint(caller, shares);
        }

        IRiskManager riskManager = IVaultModule(address(vault_)).riskManager();
        riskManager.modifyVaultBalance(asset_, int256(uint256(assets)));
        vault_.callHook(assets);

        emit Deposited(caller, referral, assets);
    }
}
