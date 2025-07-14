// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SignatureQueue.sol";

contract SignatureDepositQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_, address consensusFactory_)
        SignatureQueue(name_, version_, consensusFactory_)
    {}

    function deposit(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        TransferLibrary.receiveAssets(order.asset, order.caller, order.ordered);

        IShareModule vault_ = IShareModule(vault());

        TransferLibrary.sendAssets(order.asset, address(vault_), order.ordered);
        vault_.callHook(order.ordered);
        IVaultModule(address(vault_)).riskManager().modifyVaultBalance(order.asset, int256(order.ordered));
        vault_.shareManager().mint(order.recipient, order.requested);
        emit OrderExecuted(order, signatures);
    }
}
