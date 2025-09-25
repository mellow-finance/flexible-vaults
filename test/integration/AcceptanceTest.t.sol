// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../scripts/common/AcceptanceLibrary.sol";
import "../../scripts/ethereum/Constants.sol";

contract Integration is Test {
    function testTqETHDeployment_NO_CI() external {
        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(
            Constants.protocolDeployment(), Constants.getTqETHPreProdDeployment()
        );
    }

    function testStrETHDeployment_NO_CI() external {
        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
        AcceptanceLibrary.runVaultDeploymentChecks(Constants.protocolDeployment(), Constants.getStrETHDeployment());
    }
}
