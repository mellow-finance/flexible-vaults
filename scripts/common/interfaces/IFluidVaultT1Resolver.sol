// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IFluidVault.sol";

interface IFluidVaultT1Resolver {
    struct Configs {
        uint16 supplyRateMagnifier;
        uint16 borrowRateMagnifier;
        uint16 collateralFactor;
        uint16 liquidationThreshold;
        uint16 liquidationMaxLimit;
        uint16 withdrawalGap;
        uint16 liquidationPenalty;
        uint16 borrowFee;
        address oracle;
        uint256 oraclePriceOperate;
        uint256 oraclePriceLiquidate;
        address rebalancer;
    }

    struct ExchangePricesAndRates {
        uint256 lastStoredLiquiditySupplyExchangePrice;
        uint256 lastStoredLiquidityBorrowExchangePrice;
        uint256 lastStoredVaultSupplyExchangePrice;
        uint256 lastStoredVaultBorrowExchangePrice;
        uint256 liquiditySupplyExchangePrice;
        uint256 liquidityBorrowExchangePrice;
        uint256 vaultSupplyExchangePrice;
        uint256 vaultBorrowExchangePrice;
        uint256 supplyRateVault;
        uint256 borrowRateVault;
        uint256 supplyRateLiquidity;
        uint256 borrowRateLiquidity;
        uint256 rewardsRate; // rewards rate in percent 1e2 precision (1% = 100, 100% = 10000)
    }

    struct TotalSupplyAndBorrow {
        uint256 totalSupplyVault;
        uint256 totalBorrowVault;
        uint256 totalSupplyLiquidity;
        uint256 totalBorrowLiquidity;
        uint256 absorbedSupply;
        uint256 absorbedBorrow;
    }

    struct LimitsAndAvailability {
        uint256 withdrawLimit;
        uint256 withdrawableUntilLimit;
        uint256 withdrawable;
        uint256 borrowLimit;
        uint256 borrowableUntilLimit; // borrowable amount until any borrow limit (incl. max utilization limit)
        uint256 borrowable; // actual currently borrowable amount (borrow limit - already borrowed) & considering balance, max utilization
        uint256 borrowLimitUtilization; // borrow limit for `maxUtilization` config at Liquidity
        uint256 minimumBorrowing;
    }

    struct CurrentBranchState {
        uint256 status; // if 0 then not liquidated, if 1 then liquidated, if 2 then merged, if 3 then closed
        int256 minimaTick;
        uint256 debtFactor;
        uint256 partials;
        uint256 debtLiquidity;
        uint256 baseBranchId;
        int256 baseBranchMinima;
    }

    struct VaultState {
        uint256 totalPositions;
        int256 topTick;
        uint256 currentBranch;
        uint256 totalBranch;
        uint256 totalBorrow;
        uint256 totalSupply;
        CurrentBranchState currentBranchState;
    }

    // amounts are always in normal (for withInterest already multiplied with exchange price)
    struct UserSupplyData {
        bool modeWithInterest; // true if mode = with interest, false = without interest
        uint256 supply; // user supply amount
        // the withdrawal limit (e.g. if 10% is the limit, and 100M is supplied, it would be 90M)
        uint256 withdrawalLimit;
        uint256 lastUpdateTimestamp;
        uint256 expandPercent; // withdrawal limit expand percent in 1e2
        uint256 expandDuration; // withdrawal limit expand duration in seconds
        uint256 baseWithdrawalLimit;
        // the current actual max withdrawable amount (e.g. if 10% is the limit, and 100M is supplied, it would be 10M)
        uint256 withdrawableUntilLimit;
        uint256 withdrawable; // actual currently withdrawable amount (supply - withdrawal Limit) & considering balance
    }

    // amounts are always in normal (for withInterest already multiplied with exchange price)
    struct UserBorrowData {
        bool modeWithInterest; // true if mode = with interest, false = without interest
        uint256 borrow; // user borrow amount
        uint256 borrowLimit;
        uint256 lastUpdateTimestamp;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseBorrowLimit;
        uint256 maxBorrowLimit;
        uint256 borrowableUntilLimit; // borrowable amount until any borrow limit (incl. max utilization limit)
        uint256 borrowable; // actual currently borrowable amount (borrow limit - already borrowed) & considering balance, max utilization
        uint256 borrowLimitUtilization; // borrow limit for `maxUtilization`
    }

    struct VaultEntireData {
        address vault;
        IFluidVault.ConstantViews constantVariables;
        Configs configs;
        ExchangePricesAndRates exchangePricesAndRates;
        TotalSupplyAndBorrow totalSupplyAndBorrow;
        LimitsAndAvailability limitsAndAvailability;
        VaultState vaultState;
        // liquidity related data such as supply amount, limits, expansion etc.
        UserSupplyData liquidityUserSupplyData;
        // liquidity related data such as borrow amount, limits, expansion etc.
        UserBorrowData liquidityUserBorrowData;
    }

    struct UserPosition {
        uint256 nftId;
        address owner;
        bool isLiquidated;
        bool isSupplyPosition; // if true that means borrowing is 0
        int256 tick;
        uint256 tickId;
        uint256 beforeSupply;
        uint256 beforeBorrow;
        uint256 beforeDustBorrow;
        uint256 supply;
        uint256 borrow;
        uint256 dustBorrow;
    }

    /// @dev liquidation related data
    /// @param vault address of vault
    /// @param tokenIn_ address of token in
    /// @param tokenOut_ address of token out
    /// @param tokenInAmtOne_ (without absorb liquidity) minimum of available liquidation & tokenInAmt_
    /// @param tokenOutAmtOne_ (without absorb liquidity) expected token out, collateral to withdraw
    /// @param tokenInAmtTwo_ (absorb liquidity included) minimum of available liquidation & tokenInAmt_. In most cases it'll be same as tokenInAmtOne_ but sometimes can be bigger.
    /// @param tokenOutAmtTwo_ (absorb liquidity included) expected token out, collateral to withdraw. In most cases it'll be same as tokenOutAmtOne_ but sometimes can be bigger.
    /// @dev Liquidity in Two will always be >= One. Sometimes One can provide better swaps, sometimes Two can provide better swaps. But available in Two will always be >= One
    struct LiquidationStruct {
        address vault;
        address tokenIn;
        address tokenOut;
        uint256 tokenInAmtOne;
        uint256 tokenOutAmtOne;
        uint256 tokenInAmtTwo;
        uint256 tokenOutAmtTwo;
    }

    struct AbsorbStruct {
        address vault;
        bool absorbAvailable;
    }

    function positionByNftId(uint256 nftId_)
        external
        view
        returns (UserPosition memory userPosition_, VaultEntireData memory vaultData_);
}
