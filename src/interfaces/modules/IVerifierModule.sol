// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IVerifier.sol";
import "./IACLModule.sol";
import "./IBaseModule.sol";

interface IVerifierModule is IBaseModule, IACLModule {
    struct VerifierModuleStorage {
        address verifier;
    }

    function verifier() external view returns (IVerifier);
}
