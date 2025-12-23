// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ILidoV3VaultFactory {
    struct RoleAssignment {
        address account;
        bytes32 role;
    }

    function createVaultWithDashboard(
        address defaultAdmin_,
        address nodeOperator_,
        address nodeOperatorManager_,
        uint256 nodeOperatorFeeBP_,
        uint256 confirmExpiry_,
        RoleAssignment[] calldata roleAssignments_
    ) external payable returns (address vault, address dashboard);
}
