// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/IDepositModule.sol";
import "./SignatureQueue.sol";

contract SignatureDepositQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_) SignatureQueue(name_, version_) {}

    function oracle() public view override returns (IOracle) {
        return ISharesModule(_signatureQueueStorage().vault).depositOracle();
    }

    function deposit(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        TransferLibrary.receiveAssets(order.asset, order.caller, order.ordered);

        IDepositModule vault_ = IDepositModule(vault());

        TransferLibrary.sendAssets(order.asset, address(vault_), order.requested);
        address hook = vault_.getDepositHook(order.asset);
        if (hook != address(0)) {
            IDepositHook(hook).afterDeposit(address(vault_), order.asset, order.requested);
        }
        sharesModule().sharesManager().mint(order.recipient, order.requested);
    }
}
