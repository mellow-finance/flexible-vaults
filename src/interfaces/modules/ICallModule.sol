// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IVerifier.sol";
import "./IVerifierModule.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @notice Interface for the CallModule, which enables verified low-level calls
/// @dev Requires an associated IVerifier contract to authorize each call based on payload verification
interface ICallModule is IVerifierModule {
    /// @notice Executes a low-level call to the specified address with provided value and calldata
    /// @dev The call is verified first using the configured IVerifier before execution
    /// @param where   Target contract address to invoke
    /// @param value   ETH value to send with the call
    /// @param data    Calldata for the function to execute on the target
    /// @param payload Verification payload containing the strategy used to authorize this call
    /// @return response Raw return data from the external contract call
    function call(address where, uint256 value, bytes calldata data, IVerifier.VerificationPayload calldata payload)
        external
        returns (bytes memory response);
}
