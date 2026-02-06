// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../scripts/common/AcceptanceLibrary.sol";
import "../../scripts/ethereum/Constants.sol";

contract Integration is Test {
    function testImpl_SyncDepositQueue_NO_CI() external {
        address implementation = address(Constants.protocolDeployment().syncDepositQueueImplementation);
        AcceptanceLibrary.compareBytecode(
            "SyncDepositQueue", implementation, address(new SyncDepositQueue("Mellow", 1))
        );
    }

    function testImpl_DepositQueue_NO_CI() external {
        address implementation = address(Constants.protocolDeployment().depositQueueImplementation);
        AcceptanceLibrary.compareBytecode("DepositQueue", implementation, address(new DepositQueue("Mellow", 1)));
    }

    function testImpl_RedeemQueue_NO_CI() external {
        address implementation = address(Constants.protocolDeployment().redeemQueueImplementation);
        AcceptanceLibrary.compareBytecode("RedeemQueue", implementation, address(new RedeemQueue("Mellow", 1)));
    }

    function testImpl_BurnableTokenizedShareManager_NO_CI() external {
        address implementation = address(Constants.protocolDeployment().burnableTokenizedShareManagerImplementation);
        AcceptanceLibrary.compareBytecode(
            "BurnableTokenizedShareManager", implementation, address(new BurnableTokenizedShareManager("Mellow", 1))
        );
    }

    function testImpl_MellowAccountV1_NO_CI() external {
        address implementation = address(Constants.protocolDeployment().mellowAccountV1Implementation);
        AcceptanceLibrary.compareBytecode("MellowAccountV1", implementation, address(new MellowAccountV1()));
    }
}
