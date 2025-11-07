// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ITermMaxMarket {
    /// @notice Return the tokens in TermMax Market
    /// @return ft Fixed-rate Token(bond token). Earning Fixed Income with High Certainty
    /// @return xt Intermediary Token for Collateralization and Leveraging
    /// @return gt Gearing Token
    /// @return collateral Collateral token
    /// @return underlying Underlying Token(debt)
    function tokens()
        external
        view
        returns (address ft, address xt, address gt, address collateral, address underlying);
}
