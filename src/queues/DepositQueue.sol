// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../hooks/DepositHook.sol";
import "../modules/DepositModule.sol";
import "./Queue.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract DepositQueue is Queue, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address account => uint256 assets) public requestOf;
    mapping(address account => uint256 epoch) public requestEpochOf;
    mapping(uint256 epoch => uint256 priceD18) public conversionPriceAt;

    constructor() {
        _disableInitializers();
    }

    // View functions

    function claimableOf(address account) public view returns (uint256) {
        uint256 epoch = requestEpochOf[account];
        if (epoch == 0) {
            return 0;
        }
        uint256 priceD18 = conversionPriceAt[epoch];
        if (priceD18 == 0) {
            bool hasReport;
            (hasReport, priceD18) = vault.oracle().getDepositEpochPrice(asset, epoch);
            if (!hasReport) {
                return 0;
            }
        }
        return Math.mulDiv(requestOf[account], priceD18, 1 ether);
    }

    // Mutable functions

    function initialize(address asset_, address sharesModule_) external initializer {
        __Queue_init(asset_, sharesModule_);
    }

    function request(uint256 assets, bytes32[] calldata proof) external payable nonReentrant {
        address caller = msg.sender;
        SharesModule vault_ = vault;
        if (!vault_.sharesManager().isDepositAllowed(caller, proof)) {
            revert("DepositQueue: deposit not allowed");
        }
        uint256 epoch = requestEpochOf[caller];
        if (epoch != 0) {
            if (claim(caller) == 0 && requestEpochOf[caller] != 0) {
                revert("DepositQueue: pending request");
            }
        }
        address asset_ = asset;
        if (assets == 0 || assets < DepositModule(payable(vault_)).minDeposit(asset_)) {
            revert("DepositQueue: limit underflow");
        }
        if (assets > DepositModule(payable(vault_)).maxDeposit(asset_)) {
            revert("DepositQueue: limit overflow");
        }
        TransferLibrary.receiveAssets(asset_, caller, assets);
        epoch = vault.currentEpoch();
        demandAt[epoch] += assets;
        requestOf[caller] = assets;
        requestEpochOf[caller] = epoch;
    }

    function cancelRequest() external nonReentrant {
        address caller = msg.sender;
        uint256 epoch = requestEpochOf[caller];
        if (epoch == 0) {
            revert("DepositQueue: no pending request");
        }
        address asset_ = asset;
        (bool hasReport,) = vault.oracle().getDepositEpochPrice(asset_, epoch);
        if (hasReport) {
            revert("DepositQueue: request already claimable");
        }

        uint256 assets = requestOf[caller];
        demandAt[epoch] -= assets;
        delete requestOf[caller];
        delete requestEpochOf[caller];
        TransferLibrary.sendAssets(asset_, caller, assets);
    }

    function claim(address account) public nonReentrant returns (uint256 shares) {
        uint256 epoch = requestEpochOf[account];
        uint256 priceD18 = conversionPriceAt[epoch];
        if (priceD18 == 0 && _handleEpoch(epoch)) {
            revert("DepositQueue: not claimable yet");
        }
        if (priceD18 == 0) {
            priceD18 = conversionPriceAt[epoch];
        }
        uint256 assets = requestOf[account];
        shares = Math.mulDiv(assets, priceD18, 1 ether);
        delete requestOf[account];
        delete requestEpochOf[account];
        if (shares != 0) {
            vault.sharesManager().mintAllocatedShares(account, shares);
        }
    }

    // Internal functions

    function _handleEpoch(uint256 epoch) internal override returns (bool) {
        SharesModule vault_ = vault;
        address asset_ = asset;
        (bool hasReport, uint256 priceD18) = vault_.oracle().getDepositEpochPrice(asset_, epoch);
        if (!hasReport) {
            return false;
        }
        if (priceD18 == 0) {
            revert("DepositQueue: zero price");
        }
        uint256 demand = demandAt[epoch];
        if (demand != 0) {
            uint256 shares = Math.mulDiv(demand, priceD18, 1 ether);
            address hook = DepositModule(payable(vault_)).depositHook(asset);
            Address.functionDelegateCall(hook, abi.encodeCall(DepositHook.hook, (asset, demand)));
            vault_.sharesManager().allocateShares(shares);
            conversionPriceAt[epoch] = priceD18;
            delete demandAt[epoch];
        }
        return true;
    }
}
