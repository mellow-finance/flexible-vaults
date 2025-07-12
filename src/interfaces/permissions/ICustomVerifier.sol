// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @notice Interface for external/custom verification logic
/// @dev Allows plug-in modules to define arbitrary logic for verifying function calls.
///      Used with `VerificationType.CUSTOM_VERIFIER` in the main Verifier contract.
interface ICustomVerifier {
    /// @notice Verifies whether the given call is permitted using custom logic
    /// @param who               Address attempting the call
    /// @param where             Target contract the call is directed to
    /// @param value             ETH value sent with the call
    /// @param callData          Full calldata of the intended call
    /// @param verificationData  Extra data provided by the caller to support verification logic
    /// @return isValid          True if the call is considered valid, false otherwise
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) external view returns (bool);
}
