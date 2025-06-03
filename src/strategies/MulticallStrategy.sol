// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/CallModule.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MulticallStrategy is Ownable {
    struct Call {
        address where;
        uint256 value;
        bytes data;
        BaseVerifier.VerificationPayload verificationPayload;
    }

    address public immutable vault;

    constructor(address vault_) Ownable(msg.sender) {
        require(vault_ != address(0), "Vault address cannot be zero");
        vault = vault_;
    }

    // Mutable functions

    function multicall(Call[] calldata calls) external payable onlyOwner {
        for (uint256 i = 0; i < calls.length; i++) {
            if (calls[i].where == vault) {
                CallModule(payable(vault)).call(
                    calls[i].where, calls[i].value, calls[i].data, calls[i].verificationPayload
                );
            } else {
                Address.functionCallWithValue(calls[i].where, calls[i].data, calls[i].value);
            }
        }
    }

    receive() external payable {}
}
