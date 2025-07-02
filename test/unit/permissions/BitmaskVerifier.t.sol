// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract BitmaskVerifierTest is Test {
    address who = vm.createWallet("caller").addr;
    address where = vm.createWallet("target").addr;
    bytes callData = abi.encodeWithSignature("testFunction(uint256)", 42);
    bytes wrongCallData = abi.encodeWithSignature("testFunction1(uint256,uint256)", 42, 43);

    function testValid() external {
        BitmaskVerifier verifier = new BitmaskVerifier();
        uint256 value = 100 ether;

        bytes memory bitmask = abi.encodePacked(
            bytes32(uint256(type(uint160).max)),
            bytes32(uint256(type(uint160).max)),
            bytes32(type(uint256).max),
            new bytes(callData.length)
        );
        console.logBytes32(verifier.calculateHash(bitmask, who, where, value, callData));
        console.logBytes(bitmask);
        console.logBytes(callData);
        console.log(callData.length, bitmask.length);

        bytes memory verificationData = abi.encode(
            verifier.calculateHash(bitmask, who, where, value, callData),
            bitmask // bitmask
        );

        assertTrue(verifier.verifyCall(who, where, value, callData, verificationData));
    }

    function testInvalid() external {
        BitmaskVerifier verifier = new BitmaskVerifier();
        uint256 value = 100 ether;

        bytes memory bitmask = abi.encodePacked(
            bytes32(uint256(type(uint160).max)),
            bytes32(uint256(type(uint160).max)),
            bytes32(type(uint256).max),
            new bytes(callData.length)
        );

        bytes memory verificationData =
            abi.encode(keccak256("verifier.calculateHash(bitmask, who, where, value, callData)"), bitmask);

        assertFalse(verifier.verifyCall(who, where, value, callData, verificationData));

        assertFalse(verifier.verifyCall(who, where, value, wrongCallData, verificationData));
    }
}
