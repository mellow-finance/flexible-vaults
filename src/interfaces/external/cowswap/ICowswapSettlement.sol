// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICowswapSettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;

    function invalidateOrder(bytes calldata orderUid) external;

    function domainSeparator() external view returns (bytes32);
}
