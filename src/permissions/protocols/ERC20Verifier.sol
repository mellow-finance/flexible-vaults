// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/permissions/ICustomVerifier.sol";

import "../../libraries/SlotLibrary.sol";

contract ERC20Verifier is ICustomVerifier, ContextUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct ERC20VerifierStorage {
        address vault;
        EnumerableSet.AddressSet whitelistedTokens;
        EnumerableSet.AddressSet whitelistedRecipients;
    }

    bytes32 private immutable _erc20VerifierStoragePosition;

    bytes32 public constant ADD_WHITELISTED_TOKEN = keccak256("ERC20_VERIFIER:ADD_WHITELISTED_TOKEN");
    bytes32 public constant REMOVE_WHITELISTED_TOKEN = keccak256("ERC20_VERIFIER:REMOVE_WHITELISTED_TOKEN");
    bytes32 public constant ADD_WHITELISTED_RECIPIENT = keccak256("ERC20_VERIFIER:ADD_WHITELISTED_RECIPIENT");
    bytes32 public constant REMOVE_WHITELISTED_RECIPIENT = keccak256("ERC20_VERIFIER:REMOVE_WHITELISTED_RECIPIENT");

    constructor(string memory name_, uint256 version_) {
        _erc20VerifierStoragePosition = SlotLibrary.getSlot("ERC20Verifier", name_, version_);
        _disableInitializers();
    }

    // View functions

    modifier onlyRole(bytes32 role) {
        require(IAccessControl(_erc20VerifierStorage().vault).hasRole(role, _msgSender()), "Access denied");
        _;
    }

    function isWhitelistedToken(address token) public view returns (bool) {
        return _erc20VerifierStorage().whitelistedTokens.contains(token);
    }

    function isWhitelistedRecipient(address recipient) public view returns (bool) {
        return _erc20VerifierStorage().whitelistedRecipients.contains(recipient);
    }

    function whitelistedTokens() public view returns (uint256) {
        return _erc20VerifierStorage().whitelistedTokens.length();
    }

    function whitelistedTokenAt(uint256 index) public view returns (address) {
        return _erc20VerifierStorage().whitelistedTokens.at(index);
    }

    function whitelistedRecipients() public view returns (uint256) {
        return _erc20VerifierStorage().whitelistedRecipients.length();
    }

    function whitelistedRecipientAt(uint256 index) public view returns (address) {
        return _erc20VerifierStorage().whitelistedRecipients.at(index);
    }

    function verifyCall(
        address, /* who */
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (value != 0 || callData.length != 68 || !isWhitelistedToken(where)) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        if (selector == IERC20.approve.selector || selector == IERC20.transfer.selector) {
            (address to, uint256 amount) = abi.decode(callData[4:], (address, uint256));
            if (
                to == address(0) || (selector == IERC20.transfer.selector && amount != 0) || !isWhitelistedRecipient(to)
            ) {
                return false;
            }
            if (keccak256(abi.encodeWithSelector(selector, to, value)) != keccak256(callData)) {
                return false;
            }
        } else {
            return false;
        }
        return true;
    }

    // Mutable functions

    function initialize(address vault) external initializer {
        _erc20VerifierStorage().vault = vault;
    }

    function addWhitelistedToken(address token) external onlyRole(ADD_WHITELISTED_TOKEN) {
        require(token != address(0), "ERC20Verifier: invalid token address");
        require(_erc20VerifierStorage().whitelistedTokens.add(token), "ERC20Verifier: token already whitelisted");
    }

    function removeWhitelistedToken(address token) external onlyRole(REMOVE_WHITELISTED_TOKEN) {
        require(token != address(0), "ERC20Verifier: invalid token address");
        require(_erc20VerifierStorage().whitelistedTokens.remove(token), "ERC20Verifier: token not whitelisted");
    }

    function addWhitelistedRecipient(address recipient) external onlyRole(ADD_WHITELISTED_RECIPIENT) {
        require(recipient != address(0), "ERC20Verifier: invalid recipient address");
        require(
            _erc20VerifierStorage().whitelistedRecipients.add(recipient), "ERC20Verifier: recipient already whitelisted"
        );
    }

    function removeWhitelistedRecipient(address recipient) external onlyRole(REMOVE_WHITELISTED_RECIPIENT) {
        require(recipient != address(0), "ERC20Verifier: invalid recipient address");
        require(
            _erc20VerifierStorage().whitelistedRecipients.remove(recipient), "ERC20Verifier: recipient not whitelisted"
        );
    }

    // Internal functions

    function _erc20VerifierStorage() internal view returns (ERC20VerifierStorage storage $) {
        bytes32 slot = _erc20VerifierStoragePosition;
        assembly {
            $.slot := slot
        }
    }
}
