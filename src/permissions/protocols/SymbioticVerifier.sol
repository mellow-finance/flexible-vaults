// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/permissions/ICustomVerifier.sol";

import "../../interfaces/external/symbiotic/ISymbioticRegistry.sol";

import "../../interfaces/external/symbiotic/ISymbioticStakerRewards.sol";
import "../../interfaces/external/symbiotic/ISymbioticVault.sol";

import "../../libraries/SlotLibrary.sol";

contract SymbioticVerifier is ICustomVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct SymbioticVerifierStorage {
        address vault;
        EnumerableSet.AddressSet whitelistedVaults;
        EnumerableSet.AddressSet whitelistedFarms;
        EnumerableSet.AddressSet whitelistedTokens;
    }

    bytes32 public constant ADD_WHITELISTED_VAULT_ROLE = keccak256("SYMBIOTIC_VERIFIER:ADD_WHITELISTED_VAULT_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_VAULT_ROLE =
        keccak256("SYMBIOTIC_VERIFIER:REMOVE_WHITELISTED_VAULT_ROLE");
    bytes32 public constant ADD_WHITELISTED_FARM_ROLE = keccak256("SYMBIOTIC_VERIFIER:ADD_WHITELISTED_FARM_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_FARM_ROLE = keccak256("SYMBIOTIC_VERIFIER:REMOVE_WHITELISTED_FARM_ROLE");
    bytes32 public constant ADD_WHITELISTED_TOKEN_ROLE = keccak256("SYMBIOTIC_VERIFIER:ADD_WHITELISTED_TOKEN_ROLE");
    bytes32 public constant REMOVE_WHITELISTED_TOKEN_ROLE =
        keccak256("SYMBIOTIC_VERIFIER:REMOVE_WHITELISTED_TOKEN_ROLE");

    bytes32 private immutable _symbioticVerifierStorageSlot;
    ISymbioticRegistry public immutable vaultFactory;
    ISymbioticRegistry public immutable farmFactory;

    constructor(string memory name_, uint256 version_, address vaultFactory_, address farmFactory_) {
        _symbioticVerifierStorageSlot = SlotLibrary.getSlot("SymbioticVerifier", name_, version_);
        vaultFactory = ISymbioticRegistry(vaultFactory_);
        farmFactory = ISymbioticRegistry(farmFactory_);
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

    function vault() public view returns (address) {
        return _symbioticVerifierStorage().vault;
    }

    function isWhitelistedVault(address symbioticVault) public view returns (bool) {
        return _symbioticVerifierStorage().whitelistedVaults.contains(symbioticVault);
    }

    function isWhitelistedFarm(address farm) public view returns (bool) {
        return _symbioticVerifierStorage().whitelistedFarms.contains(farm);
    }

    function isWhitelistedToken(address token) public view returns (bool) {
        return _symbioticVerifierStorage().whitelistedTokens.contains(token);
    }

    function whitelistedVaults() public view returns (uint256) {
        return _symbioticVerifierStorage().whitelistedVaults.length();
    }

    function whitelistedFarms() public view returns (uint256) {
        return _symbioticVerifierStorage().whitelistedFarms.length();
    }

    function whitelistedTokens() public view returns (uint256) {
        return _symbioticVerifierStorage().whitelistedTokens.length();
    }

    function whitelistedVaultAt(uint256 index) public view returns (address) {
        return _symbioticVerifierStorage().whitelistedVaults.at(index);
    }

    function whitelistedFarmAt(uint256 index) public view returns (address) {
        return _symbioticVerifierStorage().whitelistedFarms.at(index);
    }

    function whitelistedTokenAt(uint256 index) public view returns (address) {
        return _symbioticVerifierStorage().whitelistedTokens.at(index);
    }

    function verifyCall(
        address, /* who */
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) public view returns (bool) {
        if (value != 0 || callData.length < 4) {
            return false;
        }

        bytes4 selector = bytes4(callData[:4]);
        if (isWhitelistedVault(where)) {
            if (selector == ISymbioticVault.deposit.selector) {
                (address onBehalfOf, uint256 amount) = abi.decode(callData[4:], (address, uint256));
                if (onBehalfOf != vault() || amount == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, onBehalfOf, amount)) != keccak256(callData)) {
                    return false;
                }
            } else if (selector == ISymbioticVault.withdraw.selector) {
                (address claimer, uint256 amount) = abi.decode(callData[4:], (address, uint256));
                if (claimer != vault() || amount == 0) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, claimer, amount)) != keccak256(callData)) {
                    return false;
                }
            } else if (selector == ISymbioticVault.claim.selector) {
                (address recipient, uint256 epoch) = abi.decode(callData[4:], (address, uint256));
                if (recipient != vault()) {
                    return false;
                }
                if (keccak256(abi.encodeWithSelector(selector, recipient, epoch)) != keccak256(callData)) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (isWhitelistedFarm(where)) {
            if (selector == ISymbioticStakerRewards.claimRewards.selector) {
                (address recipient, address token, bytes memory data) =
                    abi.decode(callData[4:], (address, address, bytes));
                if (recipient != vault() || token == address(0)) {
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

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (address vault_) = abi.decode(data, (address));
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require(vault_ != address(0), "SymbioticVerifier: Vault address cannot be zero");
        $.vault = vault_;
    }

    function addWhitelistedVault(address symbioticVault) external onlyRole(ADD_WHITELISTED_VAULT_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require(vaultFactory.isEntity(symbioticVault), "SymbioticVerifier: Not a valid vault");
        require($.whitelistedVaults.add(symbioticVault), "SymbioticVerifier: Vault already whitelisted");
    }

    function removeWhitelistedVault(address symbioticVault) external onlyRole(REMOVE_WHITELISTED_VAULT_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require($.whitelistedVaults.remove(symbioticVault), "SymbioticVerifier: Vault not whitelisted");
    }

    function addWhitelistedFarm(address farm) external onlyRole(ADD_WHITELISTED_FARM_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require(farmFactory.isEntity(farm), "SymbioticVerifier: Not a valid farm");
        require($.whitelistedFarms.add(farm), "SymbioticVerifier: Farm already whitelisted");
    }

    function removeWhitelistedFarm(address farm) external onlyRole(REMOVE_WHITELISTED_FARM_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require($.whitelistedFarms.remove(farm), "SymbioticVerifier: Farm not whitelisted");
    }

    function addWhitelistedToken(address token) external onlyRole(ADD_WHITELISTED_TOKEN_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require(token != address(0), "SymbioticVerifier: Token address cannot be zero");
        require($.whitelistedTokens.add(token), "SymbioticVerifier: Token already whitelisted");
    }

    function removeWhitelistedToken(address token) external onlyRole(REMOVE_WHITELISTED_TOKEN_ROLE) {
        SymbioticVerifierStorage storage $ = _symbioticVerifierStorage();
        require($.whitelistedTokens.remove(token), "SymbioticVerifier: Token not whitelisted");
    }

    // Internal functions

    function _symbioticVerifierStorage() internal view returns (SymbioticVerifierStorage storage $) {
        bytes32 slot = _symbioticVerifierStorageSlot;
        assembly {
            $.slot := slot
        }
    }
}
