// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/*
    src: https://github.com/morpho-org/midnight/blob/main/src/Midnight.sol
*/

import {IMidnight} from "../interfaces/external/morpho/IMidnight.sol";

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
    1. проверить корректность ордера
    нужно понять как эти collaterals депозитятся - мб по одному?
    2.   

    
*/
contract MidnightTakerModule is ReentrancyGuardUpgradeable, ContextUpgradeable {
    using SafeERC20 for IERC20;

    address public owner;
    address public midnight;
    mapping(bytes32 => bool) public marketWhitelist;

    modifier onlyOwner() {
        require(_msgSender() == owner);
        _;
    }

    modifier onlyWhitelistedMarket(IMidnight.Market calldata market) {
        bytes32 id = IMidnight(midnight).touchMarket(market);
        require(marketWhitelist[id]);
        _;
    }

    function whitelistMarket(IMidnight.Market calldata market) external onlyOwner {
        require(market.maturity > block.timestamp && market.chainId == block.chainid);
    }

    // function pushAssets(address asset, uint256 assets) external onlyOwner {}
    // function pullAssets(address asset, uint256 assets) external onlyOwner {}

    function takeSellOffer(
        IMidnight.Offer calldata offer,
        bytes calldata ratifierData,
        uint256 units,
        uint256 minBuyerAssets,
        uint256 maxSellerAssets
    ) external onlyWhitelistedMarket(offer.market) {
        require(offer.maker != address(this));
        require(offer.buy);

        bytes32 marketId = IMidnight(midnight).touchMarket(offer.market);
        require(marketWhitelist[marketId]);

        (uint256 buyerAssets, uint256 sellerAssets) =
            IMidnight(midnight).take(offer, ratifierData, units, address(this), address(0), address(0), new bytes(0));

        require(buyerAssets >= minBuyerAssets);
        require(sellerAssets <= maxSellerAssets);

        // emit TakeSellOffer(offer, units, buyerAssets, sellerAssets);
    }

    function takeBuyOffer(
        IMidnight.Offer calldata offer,
        bytes calldata ratifierData,
        uint256 units,
        uint256 minBuyerAssets,
        uint256 maxSellerAssets
    ) external onlyWhitelistedMarket(offer.market) {
    }

    function supplyCollateral(IMidnight.Market calldata market, uint256 collateralIndex, uint256 assets)
        external
        onlyWhitelistedMarket(market)
    {
        address collateral = market.collateralParams[collateralIndex].token;
        if (IERC20(collateral).balanceOf(address(this)) < assets) {
            revert("Insufficient collateral");
        }
        IERC20(collateral).safeIncreaseAllowance(midnight, assets);
        IMidnight(midnight).supplyCollateral(market, collateralIndex, assets, address(this));
        // emit SupplyCollateral(market, collateral, assets);
    }

    function withdrawCollateral(IMidnight.Market calldata market, uint256 collateralIndex, uint256 assets)
        external
        onlyWhitelistedMarket(market)
    {

    }

    function withdraw(IMidnight.Market calldata market, uint256 units) external onlyWhitelistedMarket(market) {

    }

    function repay(IMidnight.Market calldata market, uint256 units) external onlyWhitelistedMarket(market) {
        IERC20(market.loanToken).safeIncreaseAllowance(midnight, units);

        IMidnight(midnight).repay(market, units, address(this), address(0), new bytes(0));

        IERC20(market.loanToken).forceApprove(midnight, 0);

        // emit Repay(market, units);
    }
}
