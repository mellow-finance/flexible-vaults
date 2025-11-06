// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUsrExternalRequestsManager {
    enum State {
        CREATED,
        COMPLETED,
        CANCELLED
    }

    struct Request {
        uint256 id;
        address provider;
        State state;
        uint256 amount;
        address token;
        uint256 minExpectedAmount;
    }

    function requestMint(address _depositTokenAddress, uint256 _amount, uint256 _minMintAmount) external;

    function cancelMint(uint256 _id) external;

    function requestBurn(uint256 _issueTokenAmount, address _withdrawalTokenAddress, uint256 _minWithdrawalAmount)
        external;

    function cancelBurn(uint256 _id) external;

    function redeem(uint256 _amount, address _withdrawalTokenAddress, uint256 _minExpectedAmount) external;
}
