// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "src/interfaces/permissions/IVerifier.sol";

/// @title IHyperliquidTradingStrategy
/// @notice Trading API for Hyperliquid.
interface IHyperliquidTradingStrategy {
    /*///////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a limit buy order is placed.
    /// @param curator The curator that initiated the action.
    /// @param asset The asset id.
    /// @param cloid Client order id.
    /// @param limitPx The limit price.
    /// @param sz The order size.
    /// @param reduceOnly Whether the order is reduce-only.
    /// @param tif Time-in-force.
    event LimitBuyOrderPlaced(
        address indexed curator,
        uint32 indexed asset,
        uint128 indexed cloid,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        uint8 tif
    );

    /// @notice Emitted when a limit sell order is placed.
    /// @param curator The curator that initiated the action.
    /// @param asset The asset id.
    /// @param cloid Client order id.
    /// @param limitPx The limit price.
    /// @param sz The order size.
    /// @param reduceOnly Whether the order is reduce-only.
    /// @param tif Time-in-force.
    event LimitSellOrderPlaced(
        address indexed curator,
        uint32 indexed asset,
        uint128 indexed cloid,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        uint8 tif
    );

    /// @notice Emitted when an order is canceled by on-chain oid.
    /// @param curator The curator that initiated the action.
    /// @param asset The asset id.
    /// @param oid The on-chain order id.
    event OrderCancelledByOid(address indexed curator, uint32 indexed asset, uint64 indexed oid);

    /// @notice Emitted when an order is canceled by client order id.
    /// @param curator The curator that initiated the action.
    /// @param asset The asset id.
    /// @param cloid The client order id.
    event OrderCancelledByCloid(address indexed curator, uint32 indexed asset, uint128 indexed cloid);

    /// @notice Emitted when spot balance is transferred to perpetuals.
    /// @param curator The curator that initiated the action.
    /// @param ntl The notional transferred.
    event SpotToPerpTransferred(address indexed curator, uint64 ntl);

    /// @notice Emitted when perpetuals balance is transferred to spot.
    /// @param curator The curator that initiated the action.
    /// @param ntl The notional transferred.
    event PerpToSpotTransferred(address indexed curator, uint64 ntl);

    /// @notice Emitted when an ERC-20 is deposited into Hyperliquid Core.
    /// @param curator The curator that initiated the action.
    /// @param token The ERC-20 token address.
    /// @param tokenIndex The Core token index.
    /// @param systemAddress The Core system address that receives the deposit.
    /// @param amount The token amount.
    event TokenDepositedToCore(
        address indexed curator, address indexed token, uint64 indexed tokenIndex, address systemAddress, uint256 amount
    );

    /// @notice Emitted when an ERC-20 is withdrawn from Hyperliquid Core to EVM.
    /// @param curator The curator that initiated the action.
    /// @param tokenIndex The Core token index.
    /// @param amount The token amount withdrawn.
    event TokenWithdrawnToEvm(address indexed curator, uint64 indexed tokenIndex, uint64 amount);

    /// @notice Emitted when HYPE is deposited into Hyperliquid Core.
    /// @param curator The curator that initiated the action.
    /// @param amount The HYPE amount deposited.
    event HypeDepositedToCore(address indexed curator, uint256 amount);

    /// @notice Emitted when HYPE is withdrawn from Hyperliquid Core to EVM.
    /// @param curator The curator that initiated the action.
    /// @param amount The HYPE amount withdrawn.
    event HypeWithdrawnToEvm(address indexed curator, uint64 amount);

    /*///////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Places a limit buy order on Hyperliquid.
    /// @param asset The asset ID for the order.
    /// @param limitPx The limit price (10^8 scaled).
    /// @param sz The order size (10^8 scaled).
    /// @param reduceOnly Whether this is a reduce-only order.
    /// @param tif Time-in-force value (use Tif library constants).
    /// @param cloid Client order ID (0 for no cloid).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function placeLimitBuyOrder(
        uint32 asset,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        uint8 tif,
        uint128 cloid,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory);

    /// @notice Places a limit sell order on Hyperliquid.
    /// @param asset The asset ID for the order.
    /// @param limitPx The limit price (10^8 scaled).
    /// @param sz The order size (10^8 scaled).
    /// @param reduceOnly Whether this is a reduce-only order.
    /// @param tif Time-in-force value (use Tif library constants).
    /// @param cloid Client order ID (0 for no cloid).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function placeLimitSellOrder(
        uint32 asset,
        uint64 limitPx,
        uint64 sz,
        bool reduceOnly,
        uint8 tif,
        uint128 cloid,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory);

    /// @notice Cancels an order by its order ID (oid).
    /// @param asset The asset ID associated with the order.
    /// @param oid The order ID to cancel.
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function cancelOrderByOid(uint32 asset, uint64 oid, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Cancels an order by its client order ID (cloid).
    /// @param asset The asset ID associated with the order.
    /// @param cloid The client order ID to cancel.
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function cancelOrderByCloid(uint32 asset, uint128 cloid, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Transfers USD balance from spot to perp market.
    /// @param ntl Notional amount to transfer (10^8 scaled).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function transferSpotToPerp(uint64 ntl, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Transfers USD balance from perp to spot market.
    /// @param ntl Notional amount to transfer (10^8 scaled).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function transferPerpToSpot(uint64 ntl, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Withdraws a token from HyperCore to HyperEVM.
    /// @param tokenIndex Hyperliquid Core token index.
    /// @param amount Amount to withdraw (10^8 scaled).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function withdrawTokenToEvm(
        uint64 tokenIndex,
        uint64 amount,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory);

    /// @notice Deposits an ERC20 token to HyperCore.
    /// @param token ERC20 token contract address.
    /// @param tokenIndex Hyperliquid Core token index.
    /// @param amount Amount to deposit (in token units).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function depositTokenToCore(
        address token,
        uint64 tokenIndex,
        uint256 amount,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory);

    /// @notice Deposits HYPE to HyperCore.
    /// @param amount Amount to deposit (in wei).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function depositHypeToCore(uint256 amount, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Withdraws HYPE from HyperCore to HyperEVM.
    /// @param amount Amount to withdraw (10^8 scaled).
    /// @param verificationPayload Verification payload for authorizing the call through the subvault.
    /// @return Return data from the subvault call.
    function withdrawHypeToEvm(uint64 amount, IVerifier.VerificationPayload calldata verificationPayload)
        external
        returns (bytes memory);

    /// @notice Computes the Core system address for a given token index.
    /// @dev System addresses have first byte 0x20 and token index encoded in big-endian in the low bytes.
    /// @param tokenIndex The token index to compute the system address for.
    /// @return The computed system address.
    function coreSystemAddress(uint64 tokenIndex) external pure returns (address);
}
