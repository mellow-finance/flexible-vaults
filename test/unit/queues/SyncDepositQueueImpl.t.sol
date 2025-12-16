// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Fixture.t.sol";
import "../../Imports.sol";

contract SyncDepositQueueTest is FixtureTest {
    function testSyncDepositQueueImpl_NO_CI() external {
        address implementation = 0x000000002E2aeaC5Fe65AaB6fE2E6AE0e44F1A3A;
        SyncDepositQueue queue = new SyncDepositQueue("Mellow", 1);

        assertEq(implementation.code, address(queue).code, "Invalid SyncDepositQueue impl");
    }
}
