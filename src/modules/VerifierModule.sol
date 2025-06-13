// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/PermissionsLibrary.sol";
import "../libraries/SlotLibrary.sol";
import "../permissions/Verifier.sol";

import "./ACLModule.sol";
import "./BaseModule.sol";

abstract contract VerifierModule is BaseModule, ACLModule {
    struct VerifierModuleStorage {
        address verifier;
    }

    bytes32 private immutable _verifierModuleStorageSlot;

    constructor(string memory name_, uint256 version_) ACLModule(name_, version_) {
        _verifierModuleStorageSlot = SlotLibrary.getSlot("Verifier", name_, version_);
    }

    // View functions

    function verifier() public view returns (Verifier) {
        return Verifier(_verifierModuleStorage().verifier);
    }

    // Internal functions

    function __VerifierModule_init(address admin_, address verifier_) internal onlyInitializing {
        if (verifier_ == address(0)) {
            revert("VerifierModule: zero guard address");
        }
        _verifierModuleStorage().verifier = verifier_;
        __ACLModule_init(admin_);
    }

    function _verifierModuleStorage() private view returns (VerifierModuleStorage storage $) {
        bytes32 slot = _verifierModuleStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
