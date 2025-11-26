// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/ISyncDepositQueue.sol";
import "../interfaces/oracles/IOracle.sol";
import "../libraries/TransferLibrary.sol";

import "./Queue.sol";

contract SyncDepositQueue is ISyncDepositQueue, Queue {

    constructor(string memory name_, uint256 version_) Queue(name_, version_) {}

    /// @inheritdoc IQueue
    function canBeRemoved() external pure returns (bool) {
        return true;
    }

    function initialize(bytes calldata data) external initializer {
        (address asset_, address shareModule_,) = abi.decode(data, (address, address, bytes));
        __Queue_init(asset_, shareModule_);
        emit Initialized(data);
    }

    /// @inheritdoc ISyncDepositQueue
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (assets == 0) {
            revert ZeroValue();
        }
        address caller = _msgSender();
        address vault_ = vault();
        if (IShareModule(vault_).isPausedQueue(address(this))) {
            revert QueuePaused();
        }
        if (!IShareModule(vault_).shareManager().isDepositorWhitelisted(caller, merkleProof)) {
            revert DepositNotAllowed();
        }

        address asset_ = asset();
        IOracle.DetailedReport memory report = IOracle(IShareModule(vault_).oracle()).getReport(asset_);
        if (report.isSuspicious || report.priceD18 == 0) {
            revert InvalidReport();
        }

        IFeeManager feeManager = IShareModule(vault_).feeManager();
        IShareManager shareManager_ = IShareModule(vault_).shareManager();
        uint256 shares = Math.mulDiv(assets, report.priceD18, 1 ether);
        uint256 feeShares = feeManager.calculateDepositFee(shares);
        if (feeShares > 0)  {
            shareManager_.mint(feeManager.feeRecipient(), feeShares);            
            shares -= feeShares;
        }
        if (shares > 0) {
            shareManager_.mint(caller, shares);
        }

        TransferLibrary.sendAssets(asset_, address(vault_), assets);
        IRiskManager riskManager = IVaultModule(address(vault_)).riskManager();
        riskManager.modifyVaultBalance(asset_, int256(uint256(assets)));
        IShareModule(vault_).callHook(assets);

        emit Deposited(caller, referral, assets);
    }

    function _handleReport(uint224 priceD18, uint32 timestamp) internal override {}
}