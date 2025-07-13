// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/// @title FenwickTreeLibrary
/// @notice Implements a 0-indexed Fenwick Tree (Binary Indexed Tree) for prefix sum operations.
/// @dev Enables efficient updates and prefix sum queries over a dynamic array.
///
/// # Overview
/// Fenwick Tree is a compact data structure optimized for cumulative frequency computations:
/// - `update(i, delta)` increments the element at index `i` by signed `delta`.
/// - `prefixSum(i)` returns the sum of elements in the range `[0, i]`.
///
/// This library provides:
/// - `O(log n)` time complexity for updates and prefix queries.
/// - `O(1)` fixed cost for extending the tree by doubling its capacity.
/// - Support only for arrays whose lengths are powers of two (2^k).
///
/// # References
/// - https://cp-algorithms.com/data_structures/fenwick.html
/// - https://en.wikipedia.org/wiki/Fenwick_tree
library FenwickTreeLibrary {
    /// @notice Thrown when initializing with an invalid length (must be power of 2 and nonzero), or during overflow.
    error InvalidLength();

    /// @notice Thrown when an index is outside the bounds of the tree.
    error IndexOutOfBounds();

    /// @notice Internal Fenwick Tree structure using a mapping as a flat array.
    struct Tree {
        /// @notice Mapping of index to its cumulative value.
        mapping(uint256 index => int256) _values;
        /// @notice Length of the tree (must be a power of 2).
        uint256 _length;
    }

    /// @notice Initializes the tree with a given length (must be > 0 and power of 2).
    /// @param tree The Fenwick tree to initialize.
    /// @param length_ The length of the tree.
    function initialize(Tree storage tree, uint256 length_) internal {
        if (tree._length != 0 || length_ == 0 || (length_ & (length_ - 1)) != 0) {
            revert InvalidLength();
        }
        tree._length = length_;
    }

    /// @notice Returns the current size of the tree.
    /// @param tree The Fenwick tree.
    /// @return The length of the tree.
    function length(Tree storage tree) internal view returns (uint256) {
        return tree._length;
    }

    /// @notice Doubles the length of the Fenwick tree while preserving internal state.
    /// @param tree The Fenwick tree to be extended.
    function extend(Tree storage tree) internal {
        uint256 length_ = tree._length;
        if (length_ >= (1 << 255)) {
            revert InvalidLength();
        }
        tree._length = length_ << 1;
        tree._values[(length_ << 1) - 1] = tree._values[length_ - 1];
    }

    /// @notice Updates the tree at the specified index by a given delta.
    /// @param tree The Fenwick tree.
    /// @param index Index to modify.
    /// @param value Value to add (can be negative).
    function modify(Tree storage tree, uint256 index, int256 value) internal {
        uint256 length_ = tree._length;
        if (index >= length_) {
            revert IndexOutOfBounds();
        }
        if (value == 0) {
            return;
        }
        _modify(tree, index, length_, value);
    }

    /// @dev Internal function to apply Fenwick update logic.
    /// @param tree The Fenwick tree.
    /// @param index Index to start updating from.
    /// @param length_ Length of the tree.
    /// @param value Value to add.
    function _modify(Tree storage tree, uint256 index, uint256 length_, int256 value) private {
        while (index < length_) {
            tree._values[index] += value;
            index |= index + 1;
        }
    }

    /// @notice Returns the prefix sum from index 0 to `index` (inclusive).
    /// @param tree The Fenwick tree.
    /// @param index Right bound index for sum (inclusive).
    /// @return prefixSum The sum of values from index 0 to `index`.
    function get(Tree storage tree, uint256 index) internal view returns (int256) {
        uint256 length_ = tree._length;
        if (index >= length_) {
            index = length_ - 1;
        }
        return _get(tree, index);
    }

    /// @dev Internal function to compute prefix sum up to `index`.
    /// @param tree The Fenwick tree.
    /// @param index Right bound index for sum (inclusive).
    /// @return prefixSum The cumulative sum up to and including `index`.
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

    /// @notice Returns the sum over the interval [from, to].
    /// @param tree The Fenwick tree.
    /// @param from Left bound index (inclusive).
    /// @param to Right bound index (inclusive).
    /// @return The sum over the specified interval.
    function get(Tree storage tree, uint256 from, uint256 to) internal view returns (int256) {
        if (from > to) {
            return 0;
        }
        return _get(tree, to) - (from == 0 ? int256(0) : _get(tree, from - 1));
    }
}
