// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/external/symbiotic/ISymbioticRegistry.sol";
import "../../interfaces/external/symbiotic/ISymbioticStakerRewards.sol";
import "../../interfaces/external/symbiotic/ISymbioticVault.sol";

import "./OwnedCustomVerifier.sol";

contract SymbioticVerifier is OwnedCustomVerifier {
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.SymbioticVerifier.CALLER_ROLE");
    bytes32 public constant MELLOW_VAULT_ROLE = keccak256("permissions.protocols.SymbioticVerifier.MELLOW_VAULT_ROLE");
    bytes32 public constant SYMBIOTIC_FARM_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.SYMBIOTIC_FARM_ROLE");
    bytes32 public constant SYMBIOTIC_VAULT_ROLE =
        keccak256("permissions.protocols.SymbioticVerifier.SYMBIOTIC_VAULT_ROLE");

    ISymbioticRegistry public immutable vaultFactory;
    ISymbioticRegistry public immutable farmFactory;

    constructor(address vaultFactory_, address farmFactory_, string memory name_, uint256 version_)
        OwnedCustomVerifier(name_, version_)
    {
        vaultFactory = ISymbioticRegistry(vaultFactory_);
        farmFactory = ISymbioticRegistry(farmFactory_);
    }

    // View functions

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) public view returns (bool) {
        if (value != 0 || callData.length < 4 || !hasRole(CALLER_ROLE, who)) {
            return false;
        }

        bytes4 selector = bytes4(callData[:4]);
        if (hasRole(SYMBIOTIC_VAULT_ROLE, where)) {
            if (selector == ISymbioticVault.deposit.selector) {
                (address onBehalfOf, uint256 amount) = abi.decode(callData[4:], (address, uint256));
                if (!hasRole(MELLOW_VAULT_ROLE, onBehalfOf) || amount == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, onBehalfOf, amount)) != keccak256(callData)) {
                    return false;
                }
            } else if (selector == ISymbioticVault.withdraw.selector) {
                (address claimer, uint256 amount) = abi.decode(callData[4:], (address, uint256));
                if (!hasRole(MELLOW_VAULT_ROLE, claimer) || amount == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, claimer, amount)) != keccak256(callData)) {
                    return false;
                }
            } else if (selector == ISymbioticVault.claim.selector) {
                (address recipient, uint256 epoch) = abi.decode(callData[4:], (address, uint256));
                if (!hasRole(MELLOW_VAULT_ROLE, recipient)) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, recipient, epoch)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (hasRole(SYMBIOTIC_FARM_ROLE, where)) {
            if (selector == ISymbioticStakerRewards.claimRewards.selector) {
                (address recipient, address token, bytes memory data) =
                    abi.decode(callData[4:], (address, address, bytes));
                if (!hasRole(MELLOW_VAULT_ROLE, recipient) || token == address(0)) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, recipient, token, data)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
        return true;
    }
}
