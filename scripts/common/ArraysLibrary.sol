// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/Imports.sol";
import "forge-std/console2.sol";

library ArraysLibrary {
    function makeAddressArray(bytes memory data) internal pure returns (address[] memory a) {
        uint256 n = data.length / 32;
        a = new address[](n);
        assembly {
            mcopy(add(a, 0x20), add(data, 0x20), mul(n, 0x20))
        }
    }

    function insert(string[] memory a, string[] memory b, uint256 from) internal pure {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
    }

    function insert(IVerifier.VerificationPayload[] memory a, IVerifier.VerificationPayload[] memory b, uint256 from)
        internal
        pure
    {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
    }

    function insert(Call[][] memory a, Call[][] memory b, uint256 from) internal pure {
        for (uint256 i = 0; i < b.length; i++) {
            a[from + i] = b[i];
        }
    }
}
