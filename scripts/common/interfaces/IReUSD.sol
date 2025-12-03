// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IInsuranceCapitalLayer {
    /**
     * @dev Deposit tokens to insurance capital layer
     * @param token Address of the token to deposit
     * @param amount Token amount to deposit
     */
    function deposit(address token, uint256 amount, uint256 minShares) external;
    /**
     * @notice Simulates a deposit operation without executing it
     * @dev This function calculates the expected shares and fees for a potential deposit
     * @param token The address of the token to deposit
     * @param amount The amount of tokens to deposit
     * @return shares The amount of shares that would be minted
     * @return depositFees The amount of fees that would be charged
     * @return isAllowed Whether the deposit would be allowed
     * @return errorMessage A descriptive message if the deposit would fail, empty string if successful
     */
    function previewDeposit(address token, uint256 amount)
        external
        view
        returns (uint256 shares, uint256 depositFees, bool isAllowed, string memory errorMessage);
}

interface IRedemptionGateway {
    /**
     * @notice Process an instant redemption through the gateway
     * @param shares Amount of shares to redeem
     * @param minPayout Minimum payout amount (slippage protection)
     */
    function redeemInstant(uint256 shares, uint256 minPayout) external;
}
