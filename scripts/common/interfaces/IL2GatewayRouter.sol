// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IL2GatewayRouter {
    function outboundTransfer(address l1Token_, address to_, uint256 amount_, bytes calldata data_)
        external
        payable
        returns (bytes memory);
}
