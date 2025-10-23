// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title ITokenMessengerV2
/// @notice Minimal interface for Circle's TokenMessengerV2.
interface ITokenMessengerV2 {
    /// @notice Emitted when a DepositForBurn message is sent.
    /// @param burnToken address of token burnt on source domain.
    /// @param amount deposit amount.
    /// @param depositor address where deposit is transferred from.
    /// @param mintRecipient address receiving minted tokens on destination domain as bytes32.
    /// @param destinationDomain destination domain.
    /// @param destinationTokenMessenger address of TokenMessenger on destination domain as bytes32.
    /// @param destinationCaller authorized caller as bytes32 of receiveMessage() on destination domain.
    /// If equal to bytes32(0), any address can broadcast the message.
    /// @param maxFee maximum fee to pay on destination domain, in units of burnToken.
    /// @param minFinalityThreshold the minimum finality at which the message should be attested to.
    /// @param hookData optional hook for execution on destination domain.
    event DepositForBurn(
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 indexed minFinalityThreshold,
        bytes hookData
    );

    /// @notice Deposits and burns tokens from sender to be minted on destination domain.
    /// Emits a `DepositForBurn` event.
    /// @dev reverts if:
    /// - given burnToken is not supported
    /// - given destinationDomain has no TokenMessenger registered
    /// - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
    /// to this contract is less than `amount`.
    /// - burn() reverts. For example, if `amount` is 0.
    /// - maxFee is greater than or equal to `amount`.
    /// - maxFee is less than `amount * minFee / MIN_FEE_MULTIPLIER`.
    /// - MessageTransmitterV2#sendMessage reverts.
    /// @param amount amount of tokens to burn
    /// @param destinationDomain destination domain to receive message on
    /// @param mintRecipient address of mint recipient on destination domain
    /// @param burnToken token to burn `amount` of, on local domain
    /// @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
    /// any address can broadcast the message.
    /// @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
    /// @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}
