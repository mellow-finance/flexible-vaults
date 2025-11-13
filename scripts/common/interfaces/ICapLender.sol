// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICapLender {
    function repay(address _asset, uint256 _amount, address _agent) external returns (uint256 repaid);
    function borrow(address _asset, uint256 _amount, address _receiver) external returns (uint256 borrowed);
}
