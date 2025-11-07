// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ISubRedManagement {
    /**
     * @dev Initiates a subscription - platform investors transfer UT tokens to the contract to subscribe.
     *
     * @param stToken The address of the corresponding ST token.
     * @param currencyToken The address of the currency token used to purchase the ST token.
     * @param amount The amount to be paid.
     * @param _deadline The deadline for the transaction.
     *
     * Notes:
     * - The transaction must be completed before the deadline.
     * - The caller must be a whitelisted user.
     *
     * Emits:
     * - Subscription: Triggered when execution is successful.
     */
    function subscribe(address stToken, address currencyToken, uint256 amount, uint256 _deadline) external;

    /**
     * @dev Initiates a redemption - platform investors transfer ST tokens to the contract for redemption.
     *
     * @param stToken The address of the ST token.
     * @param currencyToken The address of the settlement currency token.
     * @param quantity The amount of tokens to be redeemed.
     * @param deadline The expiration time of the transaction.
     *
     * Requirements:
     * - Only platform investors can call this function.
     * - The specified ST token must support redemption.
     * - The token quantity must be greater than zero.
     *
     * Emits:
     * - Redeem: Triggered when funds are successfully redeemed.
     */
    function redeem(address stToken, address currencyToken, uint256 quantity, uint256 deadline) external;
}
