// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/IMellowACL.sol";
import "./IBaseModule.sol";

interface IACLModule is IMellowACL {
    error ZeroAddress();
    error Forbidden();
}
