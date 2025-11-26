// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICapLender {
    function repay(address _asset, uint256 _amount, address _agent) external returns (uint256 repaid);
    function borrow(address _asset, uint256 _amount, address _receiver) external returns (uint256 borrowed);

    function reservesData(address _asset)
        external
        view
        returns (
            uint256 id,
            address vault,
            address debtToken,
            address interestReceiver,
            uint8 decimals,
            bool paused,
            uint256 minBorrow
        );

    function debt(address _agent, address _asset) external view returns (uint256 totalDebt);
}
