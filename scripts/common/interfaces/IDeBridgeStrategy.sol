// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "src/interfaces/permissions/IVerifier.sol";

/// @title IDeBridgeStrategy
/// @notice Interface for DeBridge bridging operations exposed by DeBridgeStrategy implementations.
interface IDeBridgeStrategy {
    /*///////////////////////////////////////////////////////////////////////////
                                     EVENTS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when DeBridge status is toggled.
    /// @param enabled True if DeBridge is enabled, false otherwise.
    event DeBridgeStatusUpdated(bool enabled);

    /// @notice Emitted when DeBridge order authority is updated.
    /// @param orderAuthority The new order authority address.
    event DeBridgeOrderAuthorityUpdated(address orderAuthority);

    /// @notice Emitted when an ERC-20 DLN bridge is initiated on the source chain.
    /// @param curator The curator that initiated the action.
    /// @param salt The curator-provided order salt.
    /// @param orderId The DLN order id.
    /// @param giveToken The token being bridged on source.
    /// @param giveAmount The amount given on source.
    /// @param takeToken The token expected on destination.
    /// @param takeAmount The amount expected on destination.
    /// @param takeChainId The destination chain id.
    /// @param recipient The destination recipient address on the destination chain.
    /// @param nativeFee The native fee paid from the subvault.
    event DlnErc20BridgeInitiated(
        address indexed curator,
        uint64 indexed salt,
        bytes32 indexed orderId,
        address giveToken,
        uint256 giveAmount,
        address takeToken,
        uint256 takeAmount,
        uint256 takeChainId,
        address recipient,
        uint256 nativeFee
    );

    /// @notice Emitted when a native DLN bridge is initiated on the source chain.
    /// @param curator The curator that initiated the action.
    /// @param salt The curator-provided order salt.
    /// @param orderId The DLN order id.
    /// @param giveAmount The native amount given on source.
    /// @param takeToken The token expected on destination.
    /// @param takeAmount The amount expected on destination.
    /// @param takeChainId The destination chain id.
    /// @param recipient The destination recipient address on the destination chain.
    /// @param nativeFee The native fee paid from the subvault.
    event DlnNativeBridgeInitiated(
        address indexed curator,
        uint64 indexed salt,
        bytes32 indexed orderId,
        uint256 giveAmount,
        address takeToken,
        uint256 takeAmount,
        uint256 takeChainId,
        address recipient,
        uint256 nativeFee
    );

    /*///////////////////////////////////////////////////////////////////////////
                                     ERRORS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when DeBridge feature is disabled.
    error DeBridgeDisabled();

    /// @notice Thrown when DeBridge is not initialized.
    error DeBridgeNotInitialized();

    /// @notice Thrown when a provided chain ID is invalid (e.g., zero).
    error InvalidChainId();

    /// @notice Thrown when the provided msg.value does not match the expected amount.
    error InvalidMsgValue();

    /*///////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Bridge an ERC-20 token via DeBridge DLN.
    /// @param giveTokenAddress The ERC-20 token address offered on the source chain.
    /// @param giveAmount The amount offered on the source chain.
    /// @param takeAmount The amount desired on the destination chain.
    /// @param takeTokenAddress The EVM token address on the destination chain.
    /// @param nativeFee The DLN native fee to include in the call value.
    /// @param salt Salt for order uniqueness.
    /// @param verificationPayloads Two-step verification payload: [0] approve, [1] DLN create order.
    /// @return orderId The unique identifier of the created DLN order.
    function bridgeErc20ViaDeBridge(
        address giveTokenAddress,
        uint256 giveAmount,
        uint256 takeAmount,
        address takeTokenAddress,
        uint256 nativeFee,
        uint64 salt,
        IVerifier.VerificationPayload[2] calldata verificationPayloads
    ) external payable returns (bytes32 orderId);

    /// @notice Bridge the native asset via DeBridge DLN.
    /// @param giveAmount The native amount to bridge (added to `nativeFee` for total call value).
    /// @param takeAmount The amount desired on the destination chain.
    /// @param takeTokenAddress The EVM token address on the destination chain.
    /// @param nativeFee The DLN native fee to include in the call value.
    /// @param salt Salt for order uniqueness.
    /// @param verificationPayload Verification payload for the DLN create order call.
    /// @return orderId The unique identifier of the created DLN order.
    function bridgeNativeViaDeBridge(
        uint256 giveAmount,
        uint256 takeAmount,
        address takeTokenAddress,
        uint256 nativeFee,
        uint64 salt,
        IVerifier.VerificationPayload calldata verificationPayload
    ) external payable returns (bytes32 orderId);

    /// @notice Returns the configured destination chain ID for DeBridge.
    function deBridgeTakeChainId() external view returns (uint256);

    /// @notice Returns true if DeBridge bridging is enabled.
    function isDeBridgeEnabled() external view returns (bool);

    /// @notice Returns the configured order authority address for DeBridge.
    function deBridgeOrderAuthority() external view returns (address);

    /// @notice Enables DeBridge bridging.
    function enableDeBridge() external;

    /// @notice Disables DeBridge bridging.
    function disableDeBridge() external;
}
