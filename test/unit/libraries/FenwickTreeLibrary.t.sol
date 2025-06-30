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

    function test() external {}
}

contract Unit is Test {
    using FenwickTreeLibrary for FenwickTreeLibrary.Tree;

    function testInitialize() public {
        FenwickWrapper fenwick = new FenwickWrapper();

        vm.expectRevert(FenwickTreeLibrary.ZeroSize.selector);
        fenwick.init(0);

        vm.expectRevert(FenwickTreeLibrary.SizeNotPowerOfTwo.selector);
        fenwick.init(3);

        fenwick.init(2);
        require(fenwick.length() == 2, "length mismatch");
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
}
