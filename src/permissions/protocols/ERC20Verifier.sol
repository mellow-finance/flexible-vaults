// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/permissions/ICustomVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../MellowACL.sol";

contract ERC20Verifier is ICustomVerifier, MellowACL {
    error ValueZero();

    bytes32 public constant ASSET_ROLE = keccak256("permissions.protocols.ERC20Verifier.ASSET_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("permissions.protocols.ERC20Verifier.CALLER_ROLE");
    bytes32 public constant RECIPIENT_ROLE = keccak256("permissions.protocols.ERC20Verifier.RECIPIENT_ROLE");

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {
        _disableInitializers();
    }

    // View functions

    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata /* verificationData */
    ) external view override returns (bool) {
        if (value != 0 || callData.length != 68 || !hasRole(ASSET_ROLE, where) || !hasRole(CALLER_ROLE, who)) {
            return false;
        }
        bytes4 selector = bytes4(callData[:4]);
        if (selector == IERC20.approve.selector || selector == IERC20.transfer.selector) {
            (address to, uint256 amount) = abi.decode(callData[4:], (address, uint256));
            if (
                to == address(0) || (selector == IERC20.transfer.selector && amount != 0)
                    || !hasRole(RECIPIENT_ROLE, to)
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

    function initialize(bytes calldata data) external initializer {
        (address admin, address[] memory holders, bytes32[] memory roles) =
            abi.decode(data, (address, address[], bytes32[]));
        if (admin == address(0)) {
            revert ValueZero();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == address(0) || roles[i] == bytes32(0)) {
                revert ValueZero();
            }
            _grantRole(roles[i], holders[i]);
        }
    }
}
