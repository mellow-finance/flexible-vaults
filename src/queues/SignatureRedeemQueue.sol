// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SignatureQueue.sol";

contract SignatureRedeemQueue is SignatureQueue {
    error InsufficientAssets(uint256 requested, uint256 available);

    constructor(string memory name_, uint256 version_, address consensusFactory_)
        SignatureQueue(name_, version_, consensusFactory_)
    {}

    function redeem(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        IShareModule vault_ = IShareModule(vault());

        if (order.requested > vault_.getLiquidAssets()) {
            revert InsufficientAssets(order.requested, vault_.getLiquidAssets());
        }

        vault_.shareManager().burn(order.recipient, order.ordered);
        vault_.callHook(order.requested);
        TransferLibrary.sendAssets(order.asset, order.recipient, order.requested);
        IVaultModule(address(vault_)).riskManager().modifyVaultBalance(order.asset, -int256(order.requested));
        emit OrderExecuted(order, signatures);
    }
}
