// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * 0-indexed FenwickTree implementation on Solidity
 * @dev docs: https://cp-algorithms.com/data_structures/fenwick.html
 * @dev docs: https://en.wikipedia.org/wiki/Fenwick_tree
 */
library FenwickTreeLibrary {
    error InvalidLength();
    error IndexOutOfBounds();

    struct Tree {
        mapping(uint256 index => int256) _values;
        uint256 _length;
    }

    function initialize(Tree storage tree, uint256 length_) internal {
        if (tree._length != 0 || length_ == 0 || (length_ & (length_ - 1)) != 0) {
            revert InvalidLength();
        }
        tree._length = length_;
    }

    function length(Tree storage tree) internal view returns (uint256) {
        return tree._length;
    }

    function extend(Tree storage tree) internal {
        uint256 length_ = tree._length;
        if (length_ >= (1 << 255)) {
            revert InvalidLength();
        }
        tree._length = length_ << 1;
        tree._values[(length_ << 1) - 1] = tree._values[length_ - 1];
    }

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

    function _modify(Tree storage tree, uint256 index, uint256 length_, int256 value) private {
        while (index < length_) {
            tree._values[index] += value;
            index |= index + 1;
        }
    }

    function get(Tree storage tree, uint256 index) internal view returns (int256) {
        uint256 length_ = tree._length;
        if (index >= length_) {
            index = length_ - 1;
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
