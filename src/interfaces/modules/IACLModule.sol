// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IMellowACL.sol";
import "./IBaseModule.sol";

interface IACLModule is IMellowACL {
    error Forbidden();
    error ZeroAddress();

    enum FundamentalRole {
        ADMIN,
        PROXY_OWNER,
        SUBVAULT_ADMIN
    }

    struct ACLModuleStorage {
        mapping(address account => uint256) fundamentalRoles;
    }

    function hasFundamentalRole(address account, FundamentalRole role) external view returns (bool);
    function requireFundamentalRole(address account, FundamentalRole role) external view;

    // Mutable functions

    function grantFundamentalRole(FundamentalRole role, address account) external;
    function revokeFundamentalRole(FundamentalRole role, address account) external;
}
