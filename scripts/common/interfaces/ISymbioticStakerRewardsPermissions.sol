// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface ISymbioticStakerRewardsPermissions is IAccessControl {
    function ADMIN_FEE_CLAIM_ROLE() external view returns (bytes32);
    function ADMIN_FEE_SET_ROLE() external view returns (bytes32);
}
