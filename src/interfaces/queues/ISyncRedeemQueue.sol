// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ISyncQueue} from "./ISyncQueue.sol";

interface ISyncRedeemQueue is ISyncQueue {
    // Errors

    /// @notice Thrown when the caller does not have the required permission.
    error Forbidden();

    /// @notice Thrown when a provided parameter exceeds the allowed maximum value.
    error TooLarge();

    /// @notice Thrown when the oracle report is older than the configured maximum age.
    error StaleReport();

    /// @notice Thrown when a redemption exceeds the remaining daily limit.
    error DailyLimitOverflow();

    /// @notice Thrown when the daily limit does not allow exact linear decay over 24 hours.
    error InvalidDailyLimit();

    /// @notice Thrown when the vault does not have enough liquid assets to process a redemption.
    /// @param requested The amount of assets required to process the redemption.
    /// @param available The amount of liquid assets currently available in the vault.
    error InsufficientAssets(uint256 requested, uint256 available);

    // Structs

    /// @notice Storage layout for the synchronous redeem queue.
    struct SyncRedeemQueueStorage {
        /// @notice Penalty applied to synchronous redemptions, denominated in D6 precision.
        uint256 penaltyD6;
        /// @notice Maximum allowed age of an oracle report, in seconds.
        uint32 maxAge;
        /// @notice Current daily limit usage, denominated in shares.
        /// @dev Usage decays linearly over time at a rate of `dailyLimit / 24 hours`.
        uint256 usage;
        /// @notice Maximum number of shares that can be synchronously redeemed over a rolling 24-hour period.
        /// @dev Must be divisible by `24 hours` to prevent rounding during linear usage decay.
        uint256 dailyLimit;
        /// @notice Timestamp of the latest usage synchronization.
        uint256 latestRequestTimestamp;
    }

    // View functions

    /// @notice Returns the role required to update synchronous redeem queue parameters.
    function SET_SYNC_REDEEM_PARAMS_ROLE() external view returns (bytes32);

    /// @notice Returns the current synchronous redeem queue parameters and usage state.
    /// @return penaltyD6 Penalty applied to synchronous redemptions, denominated in D6 precision.
    /// @return maxAge Maximum allowed age of an oracle report, in seconds.
    /// @return usage Stored daily limit usage before accounting for decay since the latest synchronization.
    /// @return dailyLimit Maximum number of shares that can be synchronously redeemed over 24 hours.
    /// @return latestRequestTimestamp Timestamp of the latest usage synchronization.
    function syncRedeemParams()
        external
        view
        returns (uint256 penaltyD6, uint32 maxAge, uint256 usage, uint256 dailyLimit, uint256 latestRequestTimestamp);

    /// @notice Returns the current usage and remaining synchronous redemption capacity.
    /// @dev Accounts for linear usage decay since the latest synchronization.
    /// @return usage Current usage after applying linear decay.
    /// @return remainingDailyLimit_ Number of shares that can currently be synchronously redeemed.
    function remainingDailyLimit() external view returns (uint256 usage, uint256 remainingDailyLimit_);

    /// @notice Returns the amount of assets currently available for synchronous redemption.
    /// @return liquidAssets The amount of liquid assets available in the vault.
    function getLiquidAssets() external view returns (uint256 liquidAssets);

    // Mutable functions

    /// @notice Updates the synchronous redeem queue parameters.
    /// @dev The caller must have `SET_SYNC_REDEEM_PARAMS_ROLE` in the vault.
    /// @param penaltyD6 Penalty applied to synchronous redemptions, denominated in D6 precision.
    /// @param maxAge Maximum allowed age of an oracle report, in seconds.
    /// @param dailyLimit Maximum number of shares that can be synchronously redeemed over 24 hours.
    function setSyncRedeemParams(uint256 penaltyD6, uint32 maxAge, uint256 dailyLimit) external;

    /// @notice Synchronously redeems shares for the underlying asset.
    /// @dev Applies the configured redemption penalty and redeem fee before calculating the asset amount.
    ///      The redemption is subject to oracle freshness, available vault liquidity, and the daily limit.
    /// @param shares Number of shares to redeem.
    /// @param receiver Address that receives the redeemed assets.
    function redeem(uint256 shares, address receiver) external;

    // Events

    /// @notice Emitted when shares are synchronously redeemed.
    /// @param account Address whose shares were burned.
    /// @param shares Total number of shares burned from the account.
    /// @param assets Number of assets transferred to the receiver.
    /// @param feeShares Number of shares minted to the fee recipient.
    event Redeemed(address indexed account, uint256 shares, uint256 assets, uint256 feeShares);

    /// @notice Emitted when synchronous redeem queue parameters are updated.
    /// @param penaltyD6 New synchronous redemption penalty, denominated in D6 precision.
    /// @param maxAge New maximum allowed oracle report age, in seconds.
    /// @param dailyLimit New maximum number of shares that can be synchronously redeemed over 24 hours.
    event SyncRedeemParamsSet(uint256 penaltyD6, uint32 maxAge, uint256 dailyLimit);
}
