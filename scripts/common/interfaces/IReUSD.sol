// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IInsuranceCapitalLayer {
    /**
     * @dev Deposit tokens to insurance capital layer
     * @param token Address of the token to deposit
     * @param amount Token amount to deposit
     */
    function deposit(address token, uint256 amount, uint256 minShares) external;
}

interface IRedemptionGateway {
    /**
     * @notice Process an instant redemption through the gateway
     * @param shares Amount of shares to redeem
     * @param minPayout Minimum payout amount (slippage protection)
     */
    function redeemInstant(uint256 shares, uint256 minPayout) external;
}
