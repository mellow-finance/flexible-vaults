// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../modules/DepositModule.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

abstract contract SharesManager {
    // Getters

    address payable public immutable vault;
    bool public hasDepositQueues;
    bool public hasWithdrawalQueues;

    bytes32 public constant SET_FLAGS_ROLE = keccak256("SHARES_MANAGER:SET_FLAGS_ROLE");

    function sharesOf(address account) public view returns (uint256) {
        return activeSharesOf(account) + claimableSharesOf(account);
    }

    function claimableSharesOf(address account) public view returns (uint256) {
        if (!hasDepositQueues) {
            return 0;
        }
        return DepositModule(vault).claimableSharesOf(account);
    }

    // Setters
    function setFlags(bool _hasDepositQueues, bool _hasWithdrawalQueues) external {
        require(
            IAccessControl(vault).hasRole(SET_FLAGS_ROLE, msg.sender),
            "SharesManager: Caller is not authorized to set flags"
        );
        hasDepositQueues = _hasDepositQueues;
        hasWithdrawalQueues = _hasWithdrawalQueues;
    }

    // Virtual functcions

    function activeSharesOf(address account) public view virtual returns (uint256);

    function mintShares(address to, uint256 shares) external virtual;

    function allocateShares(uint256 shares) external virtual;

    function mintAllocatedShares(address to, uint256 shares) external virtual;

    function redeem(address from, uint256 amount) external virtual {}

    // Events

    event SharesMinted(address indexed to, uint256 amount);

    event SharesBurned(address indexed from, uint256 amount);
}
