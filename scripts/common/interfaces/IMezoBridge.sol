// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IMezoBridge {
    /// @notice Transfers and locks the `amount` of tBTC in the contract and
    ///         calls `_bridge` function thus initiating bridging to Mezo to
    ///         the `recipient` address.
    /// @param amount Amount of tBTC to be bridged.
    /// @param recipient Recipient of the bridged tBTC.
    /// @dev Requirements:
    ///     - The amount must be equal to or greater than the minimum tBTC
    ///       amount allowed to be bridged.
    ///     - The tBTC is transferred using the allowance mechanism. The caller
    ///       must ensure the appropriate amount of tBTC is approved for the
    ///      `BitcoinBridge` contract.
    function bridgeTBTC(uint256 amount, address recipient) external;

    /// @notice Bridges the `amount` of the `ERC20Token` to the `recipient` address on Mezo.
    /// @param ERC20Token Address of the bridged ERC20 token.
    /// @param amount Amount of the bridged ERC20 token.
    /// @param recipient Recipient of the bridged ERC20 token on Mezo.
    /// @dev Requirements:
    ///      - The ERC20 token must be enabled,
    ///      - The recipient address must not be the zero address,
    ///      - The amount must be greater than or equal to the minimum ERC20 amount,
    ///      - The caller must have allowed the contract to transfer the `amount` of the `ERC20Token`.
    function bridgeERC20(address ERC20Token, uint256 amount, address recipient) external;
}
