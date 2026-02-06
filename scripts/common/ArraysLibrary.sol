// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVerifier} from "../../src/interfaces/permissions/IVerifier.sol";
import {Call} from "./interfaces/Imports.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";

library ArraysLibrary {
    function indexOf(address[] memory array, address value) internal pure returns (uint256) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function has(address[] memory array, address value) internal pure returns (bool) {
        return indexOf(array, value) != type(uint256).max;
    }

    function makeAddressArray(bytes memory data) internal pure returns (address[] memory a) {
        uint256 n = data.length / 32;
        a = new address[](n);
        bytes32 ptr;
        assembly {
            ptr := data
        }
        mcopy(ptr, data, n);
    }

    function makeBytes32Array(bytes memory data) internal pure returns (bytes32[] memory a) {
        uint256 n = data.length / 32;
        a = new bytes32[](n);
        bytes32 ptr;
        assembly {
            ptr := data
        }
        mcopy(ptr, data, n);
    }

    function makeBytes25Array(bytes memory data) internal pure returns (bytes25[] memory a) {
        uint256 n = data.length / 32;
        a = new bytes25[](n);
        bytes32 ptr;
        assembly {
            ptr := data
        }
        mcopy(ptr, data, n);
    }

    /// @dev for Paris EVM version compatibility
    function mcopy(bytes32 ptr, bytes memory data, uint256 n) internal pure {
        uint256 length;
        assembly {
            length := mload(data)
        }
        require(length >= n, "ArraysLibrary: array too small");
        assembly {
            let dst := add(ptr, 0x20)
            let src := add(data, 0x20)
            let end := add(src, mul(n, 0x20))

            for {} lt(src, end) {
                src := add(src, 0x20)
                dst := add(dst, 0x20)
            } { mstore(dst, mload(src)) }
        }
    }

    function insert(address[] memory a, address[] memory b, uint256 from) internal pure returns (uint256) {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
        return from + b.length;
    }

    function insert(string[] memory a, string[] memory b, uint256 from) internal pure returns (uint256) {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
        return from + b.length;
    }

    function insert(IVerifier.VerificationPayload[] memory a, IVerifier.VerificationPayload[] memory b, uint256 from)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
        return from + b.length;
    }

    function insert(Call[][] memory a, Call[][] memory b, uint256 from) internal pure returns (uint256) {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
        return from + b.length;
    }

    function unique(address[] memory a) internal pure returns (address[] memory b) {
        if (a.length == 0) {
            return b;
        }
        b = new address[](a.length);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
        Arrays.sort(b);
        uint256 index;
        for (uint256 i = 0; i < a.length; i++) {
            if (index > 0 && b[i] == b[index - 1]) {
                continue;
            }
            b[index++] = b[i];
        }
        assembly {
            mstore(b, index)
        }
    }
}
