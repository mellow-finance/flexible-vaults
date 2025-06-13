// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./VerifierModule.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract CallModule is VerifierModule {
    using Address for address;

    // Mutable functions

    function call(
        address where,
        uint256 value,
        bytes calldata data,
        Verifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory response) {
        verifier().verifyCall(_msgSender(), where, value, data, verificationPayload);
        response = Address.functionCallWithValue(payable(where), data, value);
    }
}
