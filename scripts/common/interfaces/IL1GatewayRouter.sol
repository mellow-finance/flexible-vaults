// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IL1GatewayRouter {
    function outboundTransfer(
        address token_,
        address to_,
        uint256 amount_,
        uint256 maxGas_,
        uint256 gasPriceBid_,
        bytes calldata data_
    ) external payable returns (bytes memory);
}
