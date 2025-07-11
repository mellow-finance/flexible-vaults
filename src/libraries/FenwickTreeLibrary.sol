// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/*
    docs:
        https://cp-algorithms.com/data_structures/fenwick.html
        https://en.wikipedia.org/wiki/Fenwick_tree
        ru: http://e-maxx.ru/algo/fenwick_tree
*/
library FenwickTreeLibrary {
    error ZeroSize();
    error SizeNotPowerOfTwo();
    error IndexOutOfBounds();

    struct Tree {
        mapping(uint256 index => int256) array;
        uint256 size;
    }

    function initialize(Tree storage tree, uint256 size) internal {
        if (size == 0) {
            revert ZeroSize();
        }
        if ((size & (size - 1)) != 0) {
            revert SizeNotPowerOfTwo();
        }
        tree.size = size;
    }

    function length(Tree storage tree) internal view returns (uint256) {
        return tree.size;
    }

    function extend(Tree storage tree) internal {
        uint256 size = tree.size;
        tree.size = size << 1;
        /// @dev (2 ** n - 1) | (2 ** n) == 2 ** (n + 1) - 1
        tree.array[(size << 1) - 1] = tree.array[size - 1];
    }

    function modify(Tree storage tree, uint256 index, int256 value) internal {
        uint256 size = tree.size;
        if (index >= size) {
            revert IndexOutOfBounds();
        }
        if (value == 0) {
            return;
        }
        _modify(tree, index, size, value);
    }

    function _modify(Tree storage tree, uint256 index, uint256 size, int256 value) private {
        while (index < size) {
            tree.array[index] += value;
            index |= index + 1;
        }
    }

    function get(Tree storage tree, uint256 index) internal view returns (int256) {
        uint256 size = tree.size;
        if (index >= size) {
            index = size - 1;
        }
        return _get(tree, index);
    }

    function _get(Tree storage tree, uint256 index) private view returns (int256 prefixSum) {
        assembly ("memory-safe") {
            mstore(0x20, tree.slot)
            for {} 1 { index := sub(index, 1) } {
                mstore(0x00, index)
                prefixSum := add(prefixSum, sload(keccak256(0x00, 0x40)))
                index := and(index, add(index, 1))
                if iszero(index) { break }
            }
        }
    }

    function get(Tree storage tree, uint256 from, uint256 to) internal view returns (int256) {
        if (from > to) {
            return 0;
        }
        return _get(tree, to) - (from == 0 ? int256(0) : _get(tree, from - 1));
    }
}
