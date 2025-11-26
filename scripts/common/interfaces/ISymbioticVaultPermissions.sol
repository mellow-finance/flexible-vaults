// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface ISymbioticVaultPermissions is IAccessControl {
    function DEPOSIT_WHITELIST_SET_ROLE() external view returns (bytes32);
    function DEPOSITOR_WHITELIST_ROLE() external view returns (bytes32);
    function IS_DEPOSIT_LIMIT_SET_ROLE() external view returns (bytes32);
    function DEPOSIT_LIMIT_SET_ROLE() external view returns (bytes32);

    function setDepositWhitelist(bool status) external;
    function setDepositorWhitelistStatus(address account, bool status) external;
}
