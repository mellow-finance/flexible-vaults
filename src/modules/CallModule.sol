// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/ICallModule.sol";

import "./VerifierModule.sol";

abstract contract CallModule is ICallModule, VerifierModule {
    // Mutable functions

    /// @inheritdoc ICallModule
    function call(address where, uint256 value, bytes calldata data, IVerifier.VerificationPayload calldata payload)
        external
        nonReentrant
        returns (bytes memory response)
    {
        verifier().verifyCall(_msgSender(), where, value, data, payload);
        response = Address.functionCallWithValue(payable(where), data, value);
    }
}
