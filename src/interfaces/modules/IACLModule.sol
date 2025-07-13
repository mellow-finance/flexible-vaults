// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IMellowACL.sol";
import "./IBaseModule.sol";

/// @notice Interface for the ACLModule, implements IMellowACL
interface IACLModule is IMellowACL {
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Thrown when an unauthorized caller attempts a restricted operation
    error Forbidden();
}
