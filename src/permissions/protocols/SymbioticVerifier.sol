// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/permissions/ICustomVerifier.sol";

import "../../interfaces/external/symbiotic/ISymbioticVault.sol";
import "../../interfaces/external/symbiotic/ISymbioticVaultFactory.sol";

import "../../libraries/SlotLibrary.sol";

contract SymbioticVerifier is ICustomVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct SymbioticVerifierStorage {
        address vault;
    }

    bytes32 private immutable _symbioticVerifierStorageSlot;
    ISymbioticVaultFactory public immutable vaultFactory;

    constructor(string memory name_, uint256 version_, address vaultFactory_) {
        _symbioticVerifierStorageSlot = SlotLibrary.getSlot("SymbioticVerifier", name_, version_);
        vaultFactory = ISymbioticVaultFactory(vaultFactory_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(
            IAccessControl(_symbioticVerifierStorage().vault).hasRole(role, _msgSender()),
            "SymbioticVerifier: Caller does not have the required role"
        );
        _;
    }

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) external view returns (bool) {
        if (value != 0 || callData.length < 4 || !vaultFactory.isEntity(where)) {
            return false;
        }
    }

    // Mutable functions

    // Internal functions

    function _symbioticVerifierStorage() internal view returns (SymbioticVerifierStorage storage $) {
        bytes32 slot = _symbioticVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
