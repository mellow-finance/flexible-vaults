// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./SignatureQueue.sol";

contract SignatureDepositQueue is SignatureQueue {
    constructor(string memory name_, uint256 version_) SignatureQueue(name_, version_) {}

    function oracle() public view override returns (IOracle) {
        return IShareModule(_signatureQueueStorage().vault).depositOracle();
    }

    function deposit(Order calldata order, IConsensus.Signature[] calldata signatures) external payable nonReentrant {
        validateOrder(order, signatures);
        _signatureQueueStorage().nonces[order.caller]++;
        TransferLibrary.receiveAssets(order.asset, order.caller, order.ordered);

        IShareModule vault_ = IShareModule(vault());

        TransferLibrary.sendAssets(order.asset, address(vault_), order.requested);
        address hook = vault_.getHook(address(this));
        if (hook != address(0)) {
            IDepositHook(hook).afterDeposit(address(vault_), order.asset, order.requested);
        }
        IVaultModule(address(vault_)).riskManager().modifyVaultBalance(order.asset, int256(order.ordered));
        shareModule().shareManager().mint(order.recipient, order.requested);
    }
}
