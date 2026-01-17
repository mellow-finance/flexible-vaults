// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Bytes} from "@openzeppelin/contracts/utils/Bytes.sol";

enum Type {
    TUPLE, // tuple / static array
    WORD, // int8-256 / uint8-256 / bool / address / bytes1-32
    BYTES, // bytes / string
    ARRAY // dynamic array

}

struct Tree {
    Type t;
    Tree[] children;
}

/// Idea for more efficient struct Value format:
/// for Parent nodes:
///     parentMask = 1 << 255;
///     bytes value = abi.encode(childrenIndices); // or event use abi.encodePacked & 8-bit indices
///     assembly { mstore(value, or(parentMask, mload(value))) }
/// for Leaf nodes:
///     bytes value = data;
struct Value {
    bytes data;
    Value[] children;
}

library DecoderLibrary {
    error InvalidPath();
    error InvalidEncodedWord();

    function traverse(Value memory value, Tree memory tree, uint256[] memory path, uint256 index)
        internal
        pure
        returns (Value memory, Tree memory)
    {
        if (index == path.length) {
            return (value, tree);
        }
        uint256 childIndex = path[index];
        if (tree.t == Type.ARRAY) {
            return traverse(value.children[childIndex], tree.children[0], path, index + 1);
        } else if (tree.t == Type.TUPLE) {
            return traverse(value.children[childIndex], tree.children[childIndex], path, index + 1);
        } else {
            revert InvalidPath();
        }
    }

    function compare(Tree memory a, Tree memory b) internal pure returns (bool) {
        if (a.t != b.t) {
            return false;
        }
        Type t = a.t;
        if (t == Type.WORD || t == Type.BYTES) {
            return true;
        }
        if (t == Type.ARRAY) {
            return compare(a.children[0], b.children[0]);
        } else {
            if (a.children.length != b.children.length) {
                return false;
            }
            for (uint256 i = 0; i < a.children.length; i++) {
                if (!compare(a.children[i], b.children[i])) {
                    return false;
                }
            }
            return true;
        }
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

    function isValidWord(Value memory value) internal pure returns (bool) {
        return value.children.length == 0 && value.data.length == 0x20;
    }

    function at(bytes memory data, uint256 offset) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := mload(add(data, add(0x20, offset)))
        }
    }

    function align(uint256 n) internal pure returns (uint256) {
        if (n % 0x20 == 0) {
            return n;
        }
        return (n + 0x20) - (n % 0x20);
    }

    function concat(bytes[] memory array) internal pure returns (bytes memory response) {
        uint256 length = 0;
        for (uint256 i = 0; i < array.length; i++) {
            length += align(array[i].length);
        }
        response = new bytes(length);
        uint256 offset = 0x20;
        for (uint256 i = 0; i < array.length; i++) {
            bytes memory item = array[i];
            assembly {
                mcopy(add(response, offset), add(item, 0x20), mload(item))
            }
            offset += align(array[i].length);
        }
    }

    function encode(Value memory value, Tree memory tree) internal pure returns (bytes memory response) {
        if (isDynamicTree(tree)) {
            return bytes.concat(abi.encode(0x20), _encode(value, tree));
        } else {
            return _encode(value, tree);
        }
    }

    function _encode(Value memory value, Tree memory tree) private pure returns (bytes memory) {
        if (tree.t == Type.WORD) {
            if (value.data.length != 0x20) {
                revert InvalidEncodedWord();
            }
            return value.data;
        } else if (tree.t == Type.BYTES) {
            bytes memory data = value.data;
            return bytes.concat(abi.encode(data.length), data);
        } else if (tree.t == Type.ARRAY) {
            uint256 length = value.children.length;
            if (length == 0) {
                return abi.encode(length);
            }
            bytes[] memory array = new bytes[](length);
            for (uint256 i = 0; i < length; i++) {
                array[i] = _encode(value.children[i], tree.children[0]);
            }
            if (isDynamicTree(tree.children[0])) {
                bytes[] memory offsets = new bytes[](length);
                uint256 offset = 0x20 * length;
                for (uint256 i = 0; i < length; i++) {
                    offsets[i] = abi.encode(offset);
                    offset += align(array[i].length);
                }
                return bytes.concat(abi.encode(length), concat(offsets), concat(array));
            } else {
                return bytes.concat(abi.encode(length), concat(array));
            }
        } else {
            uint256 length = value.children.length;
            if (length == 0) {
                return new bytes(0);
            }
            bytes[] memory components = new bytes[](length);
            for (uint256 i = 0; i < length; i++) {
                components[i] = _encode(value.children[i], tree.children[i]);
            }
            if (isDynamicTree(tree)) {
                uint256 offset = 0;
                bytes[] memory staticComponents = new bytes[](length);
                uint256 iterator = 0;
                bool[] memory isDynamicComponent = new bool[](length);
                bytes[] memory dynamicComponents = new bytes[](length);
                for (uint256 i = 0; i < length; i++) {
                    isDynamicComponent[i] = isDynamicTree(tree.children[i]);
                    if (isDynamicComponent[i]) {
                        dynamicComponents[iterator++] = components[i];
                        offset += 0x20;
                    } else {
                        staticComponents[i] = components[i];
                        offset += align(components[i].length);
                    }
                }
                assembly {
                    mstore(dynamicComponents, iterator)
                }
                for (uint256 i = 0; i < length; i++) {
                    if (isDynamicComponent[i]) {
                        staticComponents[i] = abi.encode(offset);
                        offset += align(components[i].length);
                    }
                }

                return bytes.concat(concat(staticComponents), concat(dynamicComponents));
            } else {
                return concat(components);
            }
        }
    }

    function decode(bytes memory data, Tree memory tree) internal pure returns (Value memory result) {
        (result,) = _decode(data, isDynamicTree(tree) ? uint256(at(data, 0)) : 0, tree);
    }

    function _decode(bytes memory data, uint256 offset, Tree memory tree)
        private
        pure
        returns (Value memory result, uint256 shift)
    {
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
                    _decode(data, offset + (isDynamicTree(child) ? uint256(at(data, offset + shift)) : shift), child);
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
                    _decode(data, offset + (isDynamic ? uint256(at(data, offset + shift)) : shift), child);
                shift += shift_;
            }
            shift = 0x20;
        }
    }
}
