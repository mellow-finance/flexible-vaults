// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Bytes.sol";

library DecoderLibrary {
    enum Type {
        WORD, // int8-256 / uint8-256 / bool / address / bytes1-32
        TUPLE, // tuple / static array
        BYTES, // bytes / string
        ARRAY // dynamic array

    }

    struct Tree {
        Type t;
        Tree[] children;
    }

    struct Value {
        Type t;
        bytes data;
        Value[] children;
    }

    function isDynamicTree(Tree memory tree) internal pure returns (bool) {
        if (tree.t == Type.ARRAY || tree.t == Type.BYTES) {
            return true;
        } else if (tree.t == Type.WORD) {
            return false;
        }
        for (uint256 i = 0; i < tree.children.length; i++) {
            if (isDynamicTree(tree.children[i])) {
                return true;
            }
        }
        return false;
    }

    function at(bytes memory data, uint256 offset) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := mload(add(data, add(0x20, offset)))
        }
    }

    function decode(bytes memory data, Tree memory tree) internal pure returns (Value memory result) {
        (result,) = decode(data, isDynamicTree(tree) ? uint256(at(data, 0)) : 0, tree);
    }

    function decode(bytes memory data, uint256 offset, Tree memory tree)
        internal
        pure
        returns (Value memory result, uint256 shift)
    {
        result.t = tree.t;
        if (tree.t == Type.WORD) {
            result.data = abi.encode(at(data, offset));
            shift = 0x20;
        } else if (tree.t == Type.BYTES) {
            uint256 length = uint256(at(data, offset));
            offset += 0x20;
            result.data = Bytes.slice(data, offset, offset + length);
            shift = 0x20;
        } else if (tree.t == Type.TUPLE) {
            uint256 length = tree.children.length;
            result.children = new Value[](length);
            Tree memory child;
            uint256 shift_;
            for (uint256 i = 0; i < length; i++) {
                child = tree.children[i];
                (result.children[i], shift_) =
                    decode(data, offset + (isDynamicTree(child) ? uint256(at(data, offset + shift)) : shift), child);
                shift += shift_;
            }
        } else {
            uint256 length = uint256(at(data, offset));
            result.children = new Value[](length);
            offset += 0x20;
            uint256 shift_ = 0;
            Tree memory child = tree.children[0];
            bool isDynamic = isDynamicTree(child);
            for (uint256 i = 0; i < length; i++) {
                (result.children[i], shift_) =
                    decode(data, offset + (isDynamic ? uint256(at(data, offset + shift)) : shift), child);
                shift += shift_;
            }
            shift = 0x20;
        }
    }
}
