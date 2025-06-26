// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract Unit is Test {
    function test() external {
        BitmaskVerifier verifier = new BitmaskVerifier();
        address who = vm.createWallet("caller").addr;
        address where = vm.createWallet("target").addr;
        uint256 value = 100 ether;
        bytes memory callData = abi.encodeWithSignature("testFunction(uint256)", 42);

        bytes memory bitmask = abi.encode(
            bytes32(uint256(type(uint160).max)),
            bytes32(uint256(type(uint160).max)),
            bytes32(type(uint256).max),
            new bytes(callData.length)
        );

        bytes memory verificationData = abi.encode(
            verifier.calculateHash(bitmask, abi.encode(who, where, value, callData)),
            bitmask // bitmask
        );

        verifier.verifyCall(who, where, value, callData, verificationData);
    }
}
