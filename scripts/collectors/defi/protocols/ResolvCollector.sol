// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/libraries/TransferLibrary.sol";
import "./IDistributionCollector.sol";

import "../../../common/interfaces/IUsrExternalRequestsManager.sol";

contract ResolvCollector is IDistributionCollector {
    address public immutable usdt;
    address public immutable usdc;
    address public immutable usr;

    IUsrExternalRequestsManager public immutable requestManager;

    constructor(address usdc_, address usdt_, address usr_, address requestManager_) {
        usdc = usdc_;
        usdt = usdt_;
        usr = usr_;
        requestManager = IUsrExternalRequestsManager(requestManager_);
    }

    function getDistributions(address holder, bytes memory, /* deployment */ address[] memory /* assets */ )
        external
        view
        returns (Balance[] memory balances)
    {
        uint256 pendingUSR = 0;
        uint256 pendingUSDC = 0;
        uint256 pendingUSDT = 0;

        uint256 mintRequests = requestManager.mintRequestsCounter();
        for (uint256 id = mintRequests - 1; id > mintRequests - 10; id--) {
            (, address provider, IUsrExternalRequestsManager.State state, uint256 amount, address token,) =
                requestManager.mintRequests(id);
            if (state != IUsrExternalRequestsManager.State.CREATED || provider != holder) {
                continue;
            }
            if (token == usdc) {
                pendingUSDC += amount;
            } else if (token == usdt) {
                pendingUSDT += amount;
            } else {
                revert("Unsupported by ResolvCollector token");
            }
        }

        uint256 burnRequests = requestManager.mintRequestsCounter();
        for (uint256 id = burnRequests; id > burnRequests - 10; id--) {
            (, address provider, IUsrExternalRequestsManager.State state, uint256 amount,,) =
                requestManager.burnRequests(id);
            if (state != IUsrExternalRequestsManager.State.CREATED || provider != holder) {
                continue;
            }
            pendingUSR += amount;
        }

        balances = new Balance[](3);
        uint256 iterator = 0;
        if (pendingUSDC != 0) {
            balances[iterator++] =
                Balance({asset: usdc, balance: int256(pendingUSDC), metadata: "USRPendingMint", holder: holder});
        }

        if (pendingUSDT != 0) {
            balances[iterator++] =
                Balance({asset: usdt, balance: int256(pendingUSDT), metadata: "USRPendingMint", holder: holder});
        }

        if (pendingUSR != 0) {
            balances[iterator++] =
                Balance({asset: usr, balance: int256(pendingUSR), metadata: "USRPendingBurn", holder: holder});
        }

        assembly {
            mstore(balances, iterator)
        }
    }
}
