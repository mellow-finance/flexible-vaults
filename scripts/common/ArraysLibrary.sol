// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/Imports.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "forge-std/console2.sol";

library ArraysLibrary {
    function makeAddressArray(bytes memory data) internal pure returns (address[] memory a) {
        uint256 n = data.length / 32;
        a = new address[](n);
        assembly {
            mcopy(add(a, 0x20), add(data, 0x20), mul(n, 0x20))
        }
    }

    function makeUint24Array(bytes memory data) internal pure returns (uint24[] memory a) {
        uint256 n = data.length / 32;
        a = new uint24[](n);
        assembly {
            mcopy(add(a, 0x20), add(data, 0x20), mul(n, 0x20))
        }
    }

    function makeUint32Array(bytes memory data) internal pure returns (uint32[] memory a) {
        uint256 n = data.length / 32;
        a = new uint32[](n);
        assembly {
            mcopy(add(a, 0x20), add(data, 0x20), mul(n, 0x20))
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
