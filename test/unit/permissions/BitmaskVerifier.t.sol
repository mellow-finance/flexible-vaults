// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract BitmaskVerifierTest is Test {
    bytes32 constant WILDCARD_MASK = bytes32(0);

    address who = vm.createWallet("caller").addr;
    address where = vm.createWallet("target").addr;
    bytes callData = abi.encodeWithSignature("testFunction(uint256)", 42);
    bytes wrongCallData = abi.encodeWithSignature("testFunction1(uint256,uint256)", 42, 43);

    BitmaskVerifier verifier;

    function setUp() public {
        verifier = new BitmaskVerifier();
    }

    function testValid() external view {
        uint256 value = 100 ether;

        bytes memory bitmask = abi.encodePacked(WILDCARD_MASK, WILDCARD_MASK, WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData = abi.encode(
            verifier.calculateHash(bitmask, who, where, value, callData),
            bitmask // bitmask
        );

        assertTrue(verifier.verifyCall(who, where, value, callData, verificationData));
    }

    function testInvalid() external view {
        uint256 value = 100 ether;

        bytes memory bitmask = abi.encodePacked(WILDCARD_MASK, WILDCARD_MASK, WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData =
            abi.encode(keccak256("verifier.calculateHash(bitmask, who, where, value, callData)"), bitmask);

        assertFalse(verifier.verifyCall(who, where, value, callData, verificationData));

        assertFalse(verifier.verifyCall(who, where, value, wrongCallData, verificationData));
    }

    /// @notice Verifies that the `who` parameter is checked in the `verifyCall` function.
    function testVerifyCallChecksWho() external view {
        uint256 value = 1 ether;

        bytes memory bitmask =
            abi.encodePacked(bytes32(bytes20(who)), WILDCARD_MASK, WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who, where, value, callData), bitmask);

        assertTrue(verifier.verifyCall(who, where, value, callData, verificationData));

        address wrongWho = vm.addr(1);
        assertFalse(verifier.verifyCall(wrongWho, where, value, callData, verificationData));
    }

    /// @notice Verifies that multiple `who` addresses can be checked in the `verifyCall` function.
    function testVerifyCallChecksWho_Multiple() external view {
        uint256 value = 1 ether;

        address who1 = vm.addr(1);
        address who2 = vm.addr(2);
        address outsider = vm.addr(999);

        uint256 rawBitmask = ~(toUint256(who1) ^ toUint256(who2));
        bytes32 whoBitmask = bytes32(rawBitmask << 96);

        bytes memory bitmask = abi.encodePacked(whoBitmask, WILDCARD_MASK, WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who1, where, value, callData), bitmask);

        assertTrue(verifier.verifyCall(who1, where, value, callData, verificationData));
        assertTrue(verifier.verifyCall(who2, where, value, callData, verificationData));
        assertFalse(verifier.verifyCall(outsider, where, value, callData, verificationData));
    }

    /// @notice Verifies that the `where` parameter is checked in the `verifyCall` function.
    function testVerifyCallChecksWhere() external view {
        uint256 value = 1 ether;

        bytes memory bitmask =
            abi.encodePacked(WILDCARD_MASK, bytes32(bytes20(where)), WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who, where, value, callData), bitmask);

        assertTrue(verifier.verifyCall(who, where, value, callData, verificationData));

        address wrongWhere = vm.addr(1);
        assertFalse(verifier.verifyCall(who, wrongWhere, value, callData, verificationData));
    }

    /// @notice Verifies that multiple `where` addresses can be checked in the `verifyCall` function.
    function testVerifyCallChecksWhere_Multiple() external view {
        uint256 value = 1 ether;

        address where1 = vm.addr(1);
        address where2 = vm.addr(2);
        address outsider = vm.addr(999);

        uint256 rawBitmask = ~(toUint256(where1) ^ toUint256(where2));
        bytes32 whereBitmask = bytes32(rawBitmask << 96);

        bytes memory bitmask = abi.encodePacked(WILDCARD_MASK, whereBitmask, WILDCARD_MASK, new bytes(callData.length));

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who, where1, value, callData), bitmask);

        assertTrue(verifier.verifyCall(who, where1, value, callData, verificationData));
        assertTrue(verifier.verifyCall(who, where2, value, callData, verificationData));
        assertFalse(verifier.verifyCall(outsider, where, value, callData, verificationData));
    }

    /// @notice Verifies that the `value` parameter can be restricted.
    function testVerifyCallChecksValue() external view {
        uint256 baseValue = 1 ether;

        bytes32 valueBitmask = bytes32(type(uint256).max);

        bytes memory bitmask = abi.encodePacked(
            WILDCARD_MASK, // who
            WILDCARD_MASK, // where
            valueBitmask, // value
            new bytes(callData.length) // calldata
        );

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who, where, baseValue, callData), bitmask);

        assertTrue(verifier.verifyCall(who, where, baseValue, callData, verificationData));
        assertFalse(verifier.verifyCall(who, where, baseValue + 1 ether, callData, verificationData));
        assertFalse(verifier.verifyCall(who, where, baseValue - 1 ether, callData, verificationData));
    }

    /// @notice Verifies that the `value` parameter can be restricted to a range.
    function testVerifyCallChecksValue_Range() external view {
        uint256 baseValue = 1 ether;

        bytes32 valueBitmask = bytes32(~((uint256(1) << 60) - 1)); // [0, 2^60 - 1] -> [0, 1 ether + 15%]

        bytes memory bitmask = abi.encodePacked(
            WILDCARD_MASK, // who
            WILDCARD_MASK, // where
            valueBitmask, // value
            new bytes(callData.length) // calldata
        );

        bytes memory verificationData =
            abi.encode(verifier.calculateHash(bitmask, who, where, baseValue, callData), bitmask);

        assertTrue(verifier.verifyCall(who, where, 0, callData, verificationData));
        assertTrue(verifier.verifyCall(who, where, baseValue, callData, verificationData));
        assertFalse(verifier.verifyCall(who, where, baseValue + 1 ether, callData, verificationData));
    }

    /// @notice Verifies that the `calldata` parameter can be restricted.
    function testVerifyCallChecksCalldata() external view {
        bytes memory callData1 = abi.encodeWithSignature("testFunction(uint256)", 42);
        bytes memory callData2 = abi.encodeWithSignature("testFunction(uint256)", type(uint256).max);

        bytes memory exactBitmask = new bytes(callData1.length);
        for (uint256 i = 0; i < callData1.length; i++) {
            exactBitmask[i] = 0xFF;
        }
        bytes memory bitmask = abi.encodePacked(
            WILDCARD_MASK, // who
            WILDCARD_MASK, // where
            WILDCARD_MASK, // value
            exactBitmask // calldata
        );
        bytes memory verificationData = abi.encode(verifier.calculateHash(bitmask, who, where, 0, callData1), bitmask);
        assertTrue(verifier.verifyCall(who, where, 0, callData1, verificationData));
        assertFalse(verifier.verifyCall(who, where, 0, callData2, verificationData));
    }

    /// @notice Verifies that the `calldata` parameter can be restricted to multiple values.
    function testVerifyCallChecksCalldata_Multiple() external view {
        bytes memory callData1 = abi.encodeWithSignature("testFunction(uint256)", 42);
        bytes memory callData2 = abi.encodeWithSignature("testFunction(uint256)", type(uint256).max);
        bytes memory callData3 = abi.encodeWithSignature("testFunction(uint256)", 1234567890);

        bytes memory bitmask = abi.encodePacked(
            WILDCARD_MASK, // who
            WILDCARD_MASK, // where
            WILDCARD_MASK, // value
            createCommonBitmask(callData1, callData2) // calldata
        );

        bytes memory verificationData1 = abi.encode(verifier.calculateHash(bitmask, who, where, 0, callData1), bitmask);

        bytes memory verificationData2 = abi.encode(verifier.calculateHash(bitmask, who, where, 0, callData2), bitmask);

        assertTrue(verifier.verifyCall(who, where, 0, callData1, verificationData1));
        assertTrue(verifier.verifyCall(who, where, 0, callData2, verificationData1));
        assertTrue(verifier.verifyCall(who, where, 0, callData1, verificationData2));
        assertTrue(verifier.verifyCall(who, where, 0, callData2, verificationData2));
        assertFalse(verifier.verifyCall(who, where, 0, callData3, verificationData1));
        assertFalse(verifier.verifyCall(who, where, 0, callData3, verificationData2));
    }

    /// @notice Creates a common bitmask that allows multiple calldata by masking only identical bits
    function createCommonBitmask(bytes memory data1, bytes memory data2) internal pure returns (bytes memory) {
        require(data1.length == data2.length, "Data lengths must match");
        bytes memory commonMask = new bytes(data1.length);
        for (uint256 i = 0; i < data1.length; i++) {
            commonMask[i] = ~(data1[i] ^ data2[i]);
        }
        return commonMask;
    }

    function toUint256(address addr) private pure returns (uint256) {
        return uint256(uint160(addr));
    }
}
