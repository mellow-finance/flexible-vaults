// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IStUSR {
    function deposit(uint256 _usrAmount) external;

    function withdraw(uint256 _usrAmount) external;

    function withdrawAll() external;
}
