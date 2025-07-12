// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/permissions/ICustomVerifier.sol";
import "../MellowACL.sol";

abstract contract OwnedCustomVerifier is ICustomVerifier, MellowACL {
    error ZeroValue();

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {
        _disableInitializers();
    }

    // Mutable functions

    function initialize(bytes calldata data) external initializer {
        (address admin, address[] memory holders, bytes32[] memory roles) =
            abi.decode(data, (address, address[], bytes32[]));
        if (admin == address(0)) {
            revert ZeroValue();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == address(0) || roles[i] == bytes32(0)) {
                revert ZeroValue();
            }
            _grantRole(roles[i], holders[i]);
        }
    }
}
