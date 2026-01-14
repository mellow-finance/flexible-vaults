// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Bytes.sol";

library DecoderLibrary {
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

    struct Value {
        Type t;
        bytes data;
        Value[] children;
    }

    struct Edge {
        Type t;
        uint256 parent;
    }

    function buildTree(bytes memory data) internal pure returns (Tree memory) {
        Edge[] memory edges = abi.decode(data, (Edge[]));
        uint256 n = edges.length;
        uint256[] memory counters = new uint256[](n);
        uint256[] memory iterators = new uint256[](n);
        for (uint256 i = 1; i < n; i++) {
            uint256 parent = edges[i].parent;
            require(parent < i);
            counters[parent]++;
        }
        Tree[] memory nodes = new Tree[](n);
        for (uint256 i = 0; i < n; i++) {
            nodes[i] = Tree(edges[i].t, new Tree[](counters[i]));
            if (i > 0) {
                uint256 parent = edges[i].parent;
                nodes[parent].children[iterators[parent]++] = nodes[i];
            }
        }
        return nodes[0];
    }

    function traverse(Value memory value, uint256[] memory path, uint256 index) internal pure returns (Value memory) {
        if (index == path.length) {
            return value;
        }
        if (value.t != Type.ARRAY && value.t != Type.TUPLE) {
            revert("Invalid path");
        }
        return traverse(value.children[path[index]], path, index + 1);
    }

    function getTypeHash(Tree memory tree) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(tree.t));
        for (uint256 i = 0; i < tree.children.length; i++) {
            hash_ = keccak256(abi.encode(hash_, getTypeHash(tree.children[i])));
        }
    }

    function getTypeHash(Value memory value) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(value.t));
        for (uint256 i = 0; i < value.children.length; i++) {
            hash_ = keccak256(abi.encode(hash_, getTypeHash(value.children[i])));
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

    function isDynamicTree(Value memory tree) internal pure returns (bool) {
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

    function align(uint256 n) internal pure returns (uint256) {
        if (n % 0x20 == 0) {
            return n;
        }
        return (n + 0x20) - (n % 0x20);
    }

    function getSize(Value memory value) internal pure returns (uint256 size) {
        if (value.t == Type.WORD) {
            return 0x20;
        } else if (value.t == Type.BYTES) {
            return 0x40 + align(value.data.length);
        } else if (value.t == Type.ARRAY) {
            size = 0x40;
            uint256 length = value.children.length;
            for (uint256 i = 0; i < length; i++) {
                size += getSize(value.children[i]);
            }
            return size;
        } else {
            uint256 length = value.children.length;
            for (uint256 i = 0; i < length; i++) {
                size += getSize(value.children[i]);
            }
            return size;
        }
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

    function encode(Value memory value) internal pure returns (bytes memory response) {
        if (isDynamicTree(value)) {
            return bytes.concat(abi.encode(0x20), _encode(value));
        } else {
            return _encode(value);
        }
    }

    function _encode(Value memory value) private pure returns (bytes memory) {
        if (value.t == Type.WORD) {
            return value.data;
        } else if (value.t == Type.BYTES) {
            bytes memory data = value.data;
            return bytes.concat(abi.encode(data.length), data);
        } else if (value.t == Type.ARRAY) {
            uint256 length = value.children.length;
            if (length == 0) {
                return abi.encode(length);
            }
            bytes[] memory array = new bytes[](length);
            for (uint256 i = 0; i < length; i++) {
                array[i] = _encode(value.children[i]);
            }
            if (isDynamicTree(value.children[0])) {
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
                components[i] = _encode(value.children[i]);
            }
            if (isDynamicTree(value)) {
                uint256 offset = 0;
                bytes[] memory staticComponents = new bytes[](length);
                uint256 iterator = 0;
                bool[] memory isDynamicComponent = new bool[](length);
                bytes[] memory dynamicComponents = new bytes[](length);
                for (uint256 i = 0; i < length; i++) {
                    isDynamicComponent[i] = isDynamicTree(value.children[i]);
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
