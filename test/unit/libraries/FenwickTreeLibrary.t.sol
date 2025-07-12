// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../Imports.sol";

contract FenwickWrapper {
    using FenwickTreeLibrary for FenwickTreeLibrary.Tree;

    FenwickTreeLibrary.Tree public tree;

    function init(uint256 size) external {
        tree.initialize(size);
    }

    function length() external view returns (uint256) {
        return tree.length();
    }

    function extend() external {
        return tree.extend();
    }

    function modify(uint256 index, int256 value) external {
        return tree.modify(index, value);
    }

    function get(uint256 index) external view returns (int256) {
        return tree.get(index);
    }

    function get(uint256 from, uint256 to) external view returns (int256) {
        return tree.get(from, to);
    }

    function storageSetLimit(uint256 newLimit) external {
        tree._length = newLimit;
    }

    function test() external {}
}

contract Unit is Test {
    using FenwickTreeLibrary for FenwickTreeLibrary.Tree;

    function testInitialize() public {
        FenwickWrapper fenwick = new FenwickWrapper();

        vm.expectRevert(FenwickTreeLibrary.InvalidLength.selector);
        fenwick.init(0);

        vm.expectRevert(FenwickTreeLibrary.InvalidLength.selector);
        fenwick.init(3);

        fenwick.init(1);
        require(fenwick.length() == 1, "length mismatch");

        vm.expectRevert(FenwickTreeLibrary.InvalidLength.selector);
        fenwick.init(2);
        fenwick.storageSetLimit(1 << 255);
        vm.expectRevert(FenwickTreeLibrary.InvalidLength.selector);
        fenwick.extend();

        fenwick.storageSetLimit(1);
        for (uint256 i = 0; i < 254; i++) {
            fenwick.extend();
            assertEq(fenwick.length(), 1 << (i + 1));
        }
    }

    function testModifyAndGet() public {
        FenwickWrapper fenwick = new FenwickWrapper();
        uint256 length = 8;

        fenwick.init(length);
        require(fenwick.length() == length, "length mismatch");

        int256[] memory elem = new int256[](fenwick.length());
        for (uint256 index = 0; index < fenwick.length(); index++) {
            elem[index] = int256(index + 1);
            fenwick.modify(index, elem[index]);
        }

        int256 sum = 0;
        for (uint256 index = 0; index < fenwick.length(); index++) {
            sum += elem[index];
            require(fenwick.get(index) == sum, "element value mismatch");
        }

        uint256 modifyIndex = 0;
        int256 modifyValue = 100;
        elem[modifyIndex] += modifyValue;
        fenwick.modify(modifyIndex, modifyValue);
        sum = 0;
        for (uint256 index = 0; index < fenwick.length(); index++) {
            sum += elem[index];
            require(fenwick.get(index) == sum, "element value mismatch");
        }

        // no revert, lib truncates invalid index
        require(fenwick.get(length + 5) == sum, "invalid sum");

        sum = 0;
        uint256 startIndex = 1;
        uint256 endIndex = 5;
        for (uint256 index = startIndex; index <= endIndex; index++) {
            sum += elem[index];
        }
        require(sum == fenwick.get(startIndex, endIndex), "invalid sum in range");

        vm.expectRevert(FenwickTreeLibrary.IndexOutOfBounds.selector);
        fenwick.modify(length, 1);

        // no revert, just early exit
        fenwick.modify(0, 0);

        require(fenwick.get(startIndex + 1, startIndex) == 0, "sum is non zero");
        require(fenwick.get(endIndex, startIndex) == 0, "sum is non zero");
    }

    function testExtend() public {
        FenwickWrapper fenwick = new FenwickWrapper();

        fenwick.init(2);
        require(fenwick.length() == 2);

        for (uint256 index = 2; index < 5; index++) {
            fenwick.extend();
            require(fenwick.length() == 2 ** index, "length mismatch");
        }

        for (uint256 index = 0; index < fenwick.length(); index++) {
            require(fenwick.get(index) == 0, "element value mismatch");
        }
    }

    function testDiff() public {
        FenwickWrapper left = new FenwickWrapper();
        FenwickWrapper right = new FenwickWrapper();
        uint256 size = 2 ** 6;

        /// @dev both trees are initialized with the same size and values
        left.init(size);
        right.init(size);

        require(left.length() == right.length(), "length mismatch");
        require(getDifferentElements(left, right) == 0, "diff index mismatch");

        for (uint256 index = size - 1; index > 0; index--) {
            /// @dev change values in both trees
            left.modify(index, int256(index + 1));
            right.modify(index, int256(index + 2));
            /// @dev check that count of different elements is correct
            assertEq(getDifferentElements(left, right), size - index, "diff index mismatch");
        }
    }

    function testFenwickTreeModifyGasUsage() external {
        FenwickWrapper tree = new FenwickWrapper();
        uint256 log2 = 20;
        uint256 n = 1 << log2;
        tree.init(n);
        uint256 calls = 1000;
        uint256 cumulativeGas = 0;

        for (uint256 i = 0; i < calls; i++) {
            uint256 index = uint256(keccak256(abi.encode(i))) % n;
            int256 value = int256(uint256(keccak256(abi.encode(i))) % type(uint128).max);
            if (i & 1 == 1) {
                value = -value;
            }
            uint256 gasBefore = gasleft();
            tree.modify(index, value);
            uint256 gasAfter = gasleft();
            cumulativeGas += gasBefore - gasAfter;
        }

        uint256 maxStorageWrites = 20000 * calls * log2;
        assertLe(cumulativeGas, maxStorageWrites);
    }

    function testFenwickTreeGetGasUsage() external {
        FenwickWrapper tree = new FenwickWrapper();
        uint256 log2 = 19;
        uint256 n = 1 << log2;
        tree.init(1);
        uint256 calls = 1000;
        uint256 cumulativeGas = 0;
        int256[] memory prefixSum = new int256[](n);
        for (uint256 i = 0; i < n; i++) {
            int256 value = int256(uint256(keccak256(abi.encode(i))) % type(uint128).max);
            if (uint256(keccak256(abi.encode(value))) & 1 == 1) {
                value = -value;
            }
            prefixSum[i] = value;
            if (i > 0) {
                prefixSum[i] += prefixSum[i - 1];
            }
            if (tree.length() == i + 1) {
                tree.extend();
            }
            tree.modify(i, value);
        }

        for (uint256 i = 0; i < calls; i++) {
            uint256 l = uint256(keccak256(abi.encode(i))) % n;
            uint256 r = uint256(keccak256(abi.encode(i, l))) % n;
            if (l > r) {
                (l, r) = (r, l);
            }
            int256 result = 0;
            uint256 gasBefore = gasleft();
            result = tree.get(l, r);
            uint256 gasAfter = gasleft();
            cumulativeGas += gasBefore - gasAfter;
            int256 expectedValue = prefixSum[r] - (l == 0 ? int256(0) : prefixSum[l - 1]);
            assertEq(result, expectedValue);
        }

        uint256 maxStorageWrites = 2000 * 2 * calls * log2;
        assertLe(cumulativeGas, maxStorageWrites);
    }

    function getDifferentElements(FenwickWrapper left, FenwickWrapper right)
        internal
        view
        returns (uint256 elemCount)
    {
        if (left.length() != right.length()) {
            revert FenwickTreeLibrary.IndexOutOfBounds();
        }
        for (uint256 index = 0; index < left.length(); index++) {
            if (left.get(index) != right.get(index)) {
                elemCount++;
            }
        }
    }
}
