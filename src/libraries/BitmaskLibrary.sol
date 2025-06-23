// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library BitmaskLibrary {
    function encodeHeader(bool checkCaller, bool checkContract, bool checkValue, bool checkSelector)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            checkCaller ? type(uint160).max : uint160(0),
            checkContract ? type(uint160).max : uint160(0),
            checkValue ? type(uint256).max : uint256(0),
            checkSelector ? type(uint32).max : uint32(0)
        );
    }

    function addBytes1(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint8).max : uint8(0));
    }

    function addBytes2(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint16).max : uint16(0));
    }

    function addBytes4(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint32).max : uint32(0));
    }

    function addBytes8(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint64).max : uint64(0));
    }

    function addBytes16(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint128).max : uint128(0));
    }

    function addBytes32(bytes memory bitmask, bool check) internal pure returns (bytes memory) {
        return abi.encodePacked(bitmask, check ? type(uint256).max : uint256(0));
    }
}
