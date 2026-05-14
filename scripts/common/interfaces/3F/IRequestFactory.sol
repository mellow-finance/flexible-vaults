// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IRequestFactory {
    /// @notice Checks if an address is a Request contract deployed by this factory.
    /// @param request The address to check
    /// @return True if the address is a Request deployed by this factory
    function isRequest(address request) external view returns (bool);
}
