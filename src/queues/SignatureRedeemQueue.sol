// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SignatureQueue.sol";

contract SignatureRedeemQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_) SignatureQueue(name_, version_) {}

    function oracle() public view override returns (IOracle) {
        return IShareModule(_signatureQueueStorage().vault).redeemOracle();
    }

    function redeem(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        IShareModule vault_ = IShareModule(vault());

        if (vault_.getLiquidAssets() < order.requested) {
            revert("SignatureRedeemQueue: insufficient liquid assets");
        }

        shareModule().shareManager().burn(order.recipient, order.requested);
        vault_.callHook(order.requested);
        TransferLibrary.sendAssets(order.asset, order.recipient, order.requested);
        IVaultModule(address(vault_)).riskManager().modifyVaultBalance(order.asset, -int256(order.requested));
    }
}
