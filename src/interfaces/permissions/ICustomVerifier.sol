// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ICustomVerifier {
    function verifyCall(
        address who,
        address where,
        uint256 value,
        bytes calldata callData,
        bytes calldata verificationData
    ) external view returns (bool);
}
