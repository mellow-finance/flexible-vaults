// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/BaseVerifier.sol";
import "../shares/SharesManager.sol";
import "./PermissionsModule.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract CallModule is PermissionsModule {
    using Address for address;

    function call(
        address where,
        uint256 value,
        bytes calldata data,
        BaseVerifier.VerificationPayload calldata verificationPayload
    ) external returns (bytes memory response) {
        verifier().verifyCall(_msgSender(), where, value, data, verificationPayload);
        response = Address.functionCallWithValue(payable(where), data, value);
    }
}
