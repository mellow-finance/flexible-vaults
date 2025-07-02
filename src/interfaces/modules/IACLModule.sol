// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IMellowACL.sol";
import "./IBaseModule.sol";

interface IACLModule is IMellowACL {
    error Forbidden();
    error ZeroAddress();

    enum FundamentalRole {
        ADMIN,
        PROXY_OWNER
    }

    struct ACLModuleStorage {
        mapping(address account => uint256) fundamentalRoles;
    }

    function hasFundamentalRole(FundamentalRole role, address account) external view returns (bool);
    function requireFundamentalRole(FundamentalRole role, address account) external view;

    // Mutable functions

    function grantFundamentalRole(FundamentalRole role, address account) external;
    function revokeFundamentalRole(FundamentalRole role, address account) external;

    // Events

    event FundamentalRoleGranted(FundamentalRole indexed role, address indexed account);
    event FundamentalRoleRevoked(FundamentalRole indexed role, address indexed account);
}
