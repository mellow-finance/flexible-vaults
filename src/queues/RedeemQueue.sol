// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/RedeemModule.sol";
import "./Queue.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RedeemQueue is Queue, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address account => mapping(uint256 epoch => uint256 shares)) public requestOf;
    mapping(uint256 epoch => uint256 assets) public pulledAssetsAt;

    function initialize(address asset_, address sharesModule_) external initializer {
        __Queue_init(asset_, sharesModule_);
    }

    function request(uint256 shares) external nonReentrant {
        address caller = msg.sender;
        SharesModule vault_ = vault;
        address asset_ = asset;
        if (shares == 0 || shares < RedeemModule(payable(vault_)).minRedeem(asset_)) {
            revert("RedeemQueue: limit underflow");
        }
        if (
            shares > RedeemModule(payable(vault_)).maxRedeem(asset_)
                || shares > vault_.sharesManager().sharesOf(caller)
        ) {
            revert("RedeemQueue: limit overflow");
        }
        vault_.sharesManager().pullShares(caller, shares);
        uint256 epoch = vault_.currentEpoch();
        requestOf[caller][epoch] += shares;
        demandAt[epoch] += shares;
    }

    function claim(address account, uint256 epoch) public returns (uint256 assets) {
        uint256 pulledAssets = pulledAssetsAt[epoch];
        uint256 requested = requestOf[account][epoch];
        if (requested == 0) {
            revert("RedeemQueue: no request");
        }
        if (pulledAssets == 0) {
            revert("RedeemQueue: epoch not processed");
        }
        assets = Math.mulDiv(pulledAssets, requested, demandAt[epoch]);
        demandAt[epoch] -= requested;
        delete requestOf[account][epoch];
        if (assets == 0) {
            return 0;
        }
        pulledAssetsAt[epoch] -= assets;
        TransferLibrary.sendAssets(asset, account, assets);
    }

    function claimableAssetsOf(address account, uint256 epoch)
        public
        view
        returns (uint256 assets)
    {
        uint256 pulledAssets = pulledAssetsAt[epoch];
        uint256 requested = requestOf[account][epoch];
        if (requested == 0) {
            return 0;
        }
        if (pulledAssets == 0) {
            return 0;
        }
        assets = Math.mulDiv(pulledAssets, requested, demandAt[epoch]);
    }

    function _handleEpoch(uint256 epoch) internal override returns (bool) {
        address asset_ = asset;
        SharesModule vault_ = vault;
        (bool hasReport, uint256 priceD18) = vault_.oracle().getRedeemEpochPrice(asset_, epoch);
        if (!hasReport) {
            return false;
        }
        uint256 demand = demandAt[epoch];
        if (demand != 0) {
            uint256 assets = Math.mulDiv(demand, priceD18, 1 ether);
            if (IERC20(asset_).balanceOf(address(vault_)) < assets) {
                return false;
            }
            uint256 balance = IERC20(asset_).balanceOf(address(vault_));
            RedeemModule(payable(vault_)).pull(asset_, assets);
            pulledAssetsAt[epoch] = IERC20(asset_).balanceOf(address(vault_)) - balance;
        }
        return true;
    }

    receive() external payable {}
}
