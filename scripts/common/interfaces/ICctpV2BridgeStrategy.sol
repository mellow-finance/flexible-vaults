// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "src/interfaces/permissions/IVerifier.sol";

/// @title ICctpV2BridgeStrategy
/// @notice Interface for CCTPv2 bridging operations exposed by CctpV2BridgeStrategy implementations.
interface ICctpV2BridgeStrategy {
    /*///////////////////////////////////////////////////////////////////////////
                                     EVENTS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when CCTPv2 status is toggled.
    /// @param enabled True if CCTPv2 is enabled, false otherwise.
    event CCTPv2StatusUpdated(bool enabled);

    /// @notice Emitted when a CCTPv2 burn-and-mint transfer is initiated on the source chain.
    /// @param curator The curator that initiated the action.
    /// @param destinationDomain The destination domain.
    /// @param amount The USDC amount to bridge.
    /// @param maxFee The max fee allowed.
    /// @param minFinalityThreshold The minimum finality threshold.
    /// @param recipient The destination recipient address on the destination domain.
    event CctpV2UsdcBridgeInitiated(
        address indexed curator,
        uint32 indexed destinationDomain,
        uint256 amount,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        address recipient
    );

    /// @notice Emitted when a CCTPv2 message is processed on the destination chain.
    /// @param curator The curator that initiated the action.
    /// @param messageHash The keccak256 hash of the message payload.
    /// @param attestationHash The keccak256 hash of the attestation payload.
    event CctpV2UsdcMessageReceived(
        address indexed curator, bytes32 indexed messageHash, bytes32 indexed attestationHash
    );

    /*///////////////////////////////////////////////////////////////////////////
                                     ERRORS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when CCTPv2 bridging is disabled.
    error CCTPv2Disabled();

    /// @notice Thrown when maxFee is not strictly less than amount.
    error MaxFeeTooHigh();

    /// @notice Thrown when the CCTPv2 message payload is empty.
    error EmptyMessage();

    /// @notice Thrown when the CCTPv2 attestation payload is empty.
    error EmptyAttestation();

    /*///////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Bridge USDC via CCTPv2.
    /// @param amount The amount of USDC to bridge.
    /// @param maxFee The maximum fee for the bridge operation.
    /// @param minFinalityThreshold The minimum finality threshold.
    /// @param verificationPayloads Two-step verification payload: [0] approve, [1] depositForBurn.
    function bridgeUsdcViaCctpV2(
        uint256 amount,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        IVerifier.VerificationPayload[2] calldata verificationPayloads
    ) external;

    /// @notice Receive USDC via CCTPv2.
    /// @param message The message from CCTPv2.
    /// @param attestation The attestation from CCTPv2.
    /// @return success True if the underlying call succeeded.
    function receiveUsdcViaCctpV2(bytes calldata message, bytes calldata attestation) external returns (bool success);

    /// @notice Returns the configured destination domain for CCTPv2.
    function cctpV2DestinationDomain() external view returns (uint32);

    /// @notice Returns the USDC address for this strategy.
    function usdc() external view returns (address);

    /// @notice Returns the configured TokenMessenger contract address for this chain.
    function cctpV2TokenMessenger() external view returns (address);

    /// @notice Returns the configured MessageTransmitter contract address for this chain.
    function cctpV2MessageTransmitter() external view returns (address);

    /// @notice Returns true if CCTPv2 bridging is enabled.
    function isCctpV2Enabled() external view returns (bool);

    /// @notice Enables CCTPv2 bridging.
    function enableCctpV2() external;

    /// @notice Disables CCTPv2 bridging.
    function disableCctpV2() external;
}
