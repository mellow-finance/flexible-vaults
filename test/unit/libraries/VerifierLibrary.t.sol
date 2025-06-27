// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract VerifierLibraryTest is Test {
    function _readBytesAppended(bytes memory data, uint256 offset, uint256 len) internal pure returns (uint256 out) {
        for (uint256 i = 0; i < len; ++i) {
            out |= uint256(uint8(data[offset + i])) << (8 * (len - 1 - i));
        }
    }

    function testAddBytes1() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes1(base, true);
        bytes memory rF = VerifierLibrary.addBytes1(base, false);
        assertEq(_readBytesAppended(rT, base.length, 1), type(uint8).max);
        assertEq(_readBytesAppended(rF, base.length, 1), 0);
    }

    function testAddBytes2() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes2(base, true);
        bytes memory rF = VerifierLibrary.addBytes2(base, false);
        assertEq(_readBytesAppended(rT, base.length, 2), type(uint16).max);
        assertEq(_readBytesAppended(rF, base.length, 2), 0);
    }

    function testAddBytes4() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes4(base, true);
        bytes memory rF = VerifierLibrary.addBytes4(base, false);
        assertEq(_readBytesAppended(rT, base.length, 4), type(uint32).max);
        assertEq(_readBytesAppended(rF, base.length, 4), 0);
    }

    function testAddBytes8() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes8(base, true);
        bytes memory rF = VerifierLibrary.addBytes8(base, false);
        assertEq(_readBytesAppended(rT, base.length, 8), type(uint64).max);
        assertEq(_readBytesAppended(rF, base.length, 8), 0);
    }

    function testAddBytes16() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes16(base, true);
        bytes memory rF = VerifierLibrary.addBytes16(base, false);
        assertEq(_readBytesAppended(rT, base.length, 16), type(uint128).max);
        assertEq(_readBytesAppended(rF, base.length, 16), 0);
    }

    function testAddBytes32() external pure {
        bytes memory base = hex"aaaa";
        bytes memory rT = VerifierLibrary.addBytes32(base, true);
        bytes memory rF = VerifierLibrary.addBytes32(base, false);
        assertEq(_readBytesAppended(rT, base.length, 32), type(uint256).max);
        assertEq(_readBytesAppended(rF, base.length, 32), 0);
    }

    function testAddCombination() external pure {
        bytes memory b = hex"cccc";
        b = VerifierLibrary.addBytes1(b, true);
        b = VerifierLibrary.addBytes2(b, false);
        b = VerifierLibrary.addBytes4(b, true);
        b = VerifierLibrary.addBytes8(b, false);
        b = VerifierLibrary.addBytes16(b, true);
        b = VerifierLibrary.addBytes32(b, false);

        uint256 offset = 2;

        assertEq(_readBytesAppended(b, offset, 1), type(uint8).max);
        offset += 1;

        assertEq(_readBytesAppended(b, offset, 2), 0);
        offset += 2;

        assertEq(_readBytesAppended(b, offset, 4), type(uint32).max);
        offset += 4;

        assertEq(_readBytesAppended(b, offset, 8), 0);
        offset += 8;

        assertEq(_readBytesAppended(b, offset, 16), type(uint128).max);
        offset += 16;

        assertEq(_readBytesAppended(b, offset, 32), 0);
    }

    function testEncodeHeaderAllTrue() external pure {
        bytes memory header = VerifierLibrary.encodeHeader(true, true, true, true);
        (uint160 caller, uint160 contractAddr, uint256 value, uint32 selector) =
            abi.decode(header, (uint160, uint160, uint256, uint32));

        assertEq(caller, type(uint160).max);
        assertEq(contractAddr, type(uint160).max);
        assertEq(value, type(uint256).max);
        assertEq(selector, type(uint32).max);
    }

    function testEncodeHeaderAllFalse() external pure {
        bytes memory header = VerifierLibrary.encodeHeader(false, false, false, false);
        (uint160 caller, uint160 contractAddr, uint256 value, uint32 selector) =
            abi.decode(header, (uint160, uint160, uint256, uint32));

        assertEq(caller, 0);
        assertEq(contractAddr, 0);
        assertEq(value, 0);
        assertEq(selector, 0);
    }

    function testEncodeHeaderMixed() external pure {
        bytes memory header = VerifierLibrary.encodeHeader(true, false, true, false);
        (uint160 caller, uint160 contractAddr, uint256 value, uint32 selector) =
            abi.decode(header, (uint160, uint160, uint256, uint32));

        assertEq(caller, type(uint160).max);
        assertEq(contractAddr, 0);
        assertEq(value, type(uint256).max);
        assertEq(selector, 0);
    }
}
