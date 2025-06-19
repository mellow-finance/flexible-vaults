// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IRedeemModule.sol";
import "./SignatureQueue.sol";

contract SignatureDepositQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_) SignatureQueue(name_, version_) {}

    function oracle() public view override returns (IOracle) {
        return ISharesModule(_signatureQueueStorage().vault).redeemOracle();
    }

    function redeem(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        IRedeemModule vault_ = IRedeemModule(vault());

        if (vault_.getLiquidAssets(order.asset) < order.requested) {
            revert("SignatureDepositQueue: insufficient liquid assets");
        }

        sharesModule().sharesManager().burn(order.recipient, order.requested);
        vault_.callRedeemHook(order.asset, order.requested);
        TransferLibrary.sendAssets(order.asset, order.recipient, order.requested);
    }
}
