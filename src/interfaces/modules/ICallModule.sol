// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IVerifier.sol";
import "./IVerifierModule.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ICallModule is IVerifierModule {
    function call(address where, uint256 value, bytes calldata data, IVerifier.VerificationPayload calldata payload)
        external
        returns (bytes memory response);
}
