// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IVerifier.sol";
import "./IBaseModule.sol";

/// @notice Interface for the VerifierModule, which integrates with an external IVerifier contract
/// @dev Used in modular systems to delegate permission checks or validation to a shared verifier
interface IVerifierModule is IBaseModule {
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Internal storage structure for VerifierModule
    struct VerifierModuleStorage {
        address verifier; // Address of the IVerifier contract used for external call validation
    }

    /// @notice Returns the current verifier contract used by the module
    /// @return Address of the IVerifier contract
    function verifier() external view returns (IVerifier);
}
