// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @notice Interface for Hyperliquid's CoreWriter contract that sends actions from HyperEVM to HyperCore.
interface ICoreWriter {
    /// @notice Emitted when an action is sent to HyperCore for execution.
    /// @param user The HyperEVM address that sent the action.
    /// @param data The encoded action data for HyperCore execution.
    event RawAction(address indexed user, bytes data);

    /// @notice Sends an encoded action to HyperCore. Burns ~25k gas and delays execution by a few seconds.
    /// @param data The encoded action (version byte + action ID + action-specific data).
    function sendRawAction(bytes calldata data) external;
}
