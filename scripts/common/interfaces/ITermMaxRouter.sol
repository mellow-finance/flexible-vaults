// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title TermMax Router interface
 * @author Term Structure Labs
 * @notice Interface for the main router contract that handles all user interactions with TermMax protocol
 * @dev This interface defines all external functions for swapping, leveraging, and managing positions
 */
interface ITermMaxRouter {
    /**
     * @notice Borrows tokens using collateral
     * @dev Creates a collateralized debt position
     * @param recipient Address to receive the borrowed tokens
     * @param market The market to borrow from
     * @param collInAmt Amount of collateral to deposit
     * @param orders Array of orders to execute
     * @param tokenAmtsWantBuy Array of token amounts to buy
     * @param maxDebtAmt Maximum amount of debt to take on
     * @param deadline The deadline timestamp for the transaction
     * @return gtId ID of the generated GT token
     */
    function borrowTokenFromCollateral(
        address recipient,
        address market,
        uint256 collInAmt,
        address[] memory orders,
        uint128[] memory tokenAmtsWantBuy,
        uint128 maxDebtAmt,
        uint256 deadline
    ) external returns (uint256 gtId);

    /**
     * @notice Repays a GT in a TermMax market
     * @param market The TermMax market to repay in
     * @param gtId The ID of the GT to repay
     * @param maxRepayAmt Maximum amount of tokens to repay
     * @param byDebtToken Whether to repay using debt tokens
     * @return repayAmt The actual amount repaid
     */
    function repayGt(address market, uint256 gtId, uint128 maxRepayAmt, bool byDebtToken)
        external
        returns (uint128 repayAmt);
}
