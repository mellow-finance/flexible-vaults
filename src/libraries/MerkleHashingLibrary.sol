// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library MerkleHashingLibrary {
    function hash(address account) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    function hash(bytes memory data) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(data)));
    }
}
