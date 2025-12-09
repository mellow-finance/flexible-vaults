// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ILayerZeroOFT.sol";

interface ILayerZeroOFTAdapter is ILayerZeroOFT {
    function token() external view returns (address);
    function approvalRequired() external pure returns (bool);
}
