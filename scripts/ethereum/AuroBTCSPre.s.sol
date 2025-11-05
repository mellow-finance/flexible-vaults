// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AuroBTCBase.sol";

contract Deploy is AuroBTCBase {
    function name() public pure override returns (string memory) {
        return "Staked Auro BTC predeposit";
    }

    function symbol() public pure override returns (string memory) {
        return "auroBTC.s.pre";
    }

    function vaultAddress() public pure override returns (address) {
        if (true) {
            revert("AuroBTCSPre: deployment not found");
        }
        return address(0xdead);
    }

    function executionType() public pure override returns (ExecutionType) {
        return ExecutionType.TEST;
    }
}
