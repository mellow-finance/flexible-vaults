// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../scripts/common/AcceptanceLibrary.sol";
import "../../scripts/ethereum/Constants.sol";

contract Integration is Test {
    function testAcceptanceTest_NO_CI() external {
        AcceptanceLibrary.runProtocolDeploymentChecks(Constants.protocolDeployment());
    }
}
