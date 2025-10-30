// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {CCIPClient} from "../libraries/CCIPClient.sol";

interface ICCIPRouterClient {
    function ccipSend(uint64 destinationChainSelector, CCIPClient.EVM2AnyMessage calldata message)
        external
        payable
        returns (bytes32);
}
