// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library StringView {
    error InvalidSymbol();

    struct View {
        string s;
        uint256 length_;
    }

    function init(string memory s) internal pure returns (View memory) {
        return View(s, bytes(s).length);
    }

    function length(View memory $) internal pure returns (uint256) {
        return $.length_;
    }

    function str(View memory $) internal pure returns (string memory) {
        return $.s;
    }

    function at(View memory $, uint256 index) internal pure returns (bytes1) {
        if (index >= $.length_) {
            revert("Out of bounds");
        }
        return bytes($.s)[index];
    }

    function toUint(View memory s) internal pure returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < s.length_; i++) {
            uint256 digit = uint8(at(s, i));
            if (digit < 48 || digit > 57) {
                revert InvalidSymbol();
            }
            value = (value * 10) + digit - 48;
        }
        return value;
    }

    function equalsTo(View memory a, View memory b) internal pure returns (bool) {
        return a.length_ == b.length_ && keccak256(bytes(a.s)) == keccak256(bytes(b.s));
    }

    function equalsTo(View memory a, string memory b) internal pure returns (bool) {
        return equalsTo(a, init(b));
    }

    function slice(View memory a, uint256 start, uint256 end) internal pure returns (View memory) {
        if (end > a.length_) {
            end = a.length_;
        }
        if (start >= end) {
            return View("", 0);
        }
        uint256 length_ = end - start;
        bytes memory response = new bytes(length_);
        for (uint256 i = 0; i < length_; i++) {
            response[i] = at(a, i + start);
        }
        return View(string(response), length_);
    }

    function endswith(View memory a, View memory b) internal pure returns (bool) {
        if (b.length_ > a.length_) {
            return false;
        }
        return equalsTo(slice(a, a.length_ - b.length_, a.length_), b);
    }

    function endswith(View memory a, string memory b) internal pure returns (bool) {
        return endswith(a, init(b));
    }

    function startswith(View memory a, View memory b) internal pure returns (bool) {
        if (b.length_ > a.length_) {
            return false;
        }
        return equalsTo(slice(a, 0, b.length_), b);
    }

    function startswith(View memory a, string memory b) internal pure returns (bool) {
        return startswith(a, init(b));
    }

    function split(View memory s, bytes1 delimiter) internal pure returns (View[] memory array) {
        uint256 n = 1;
        for (uint256 i = 0; i < s.length_; i++) {
            if (at(s, i) == delimiter) {
                ++n;
            }
        }
        array = new View[](n);
        uint256 from = 0;
        uint256 iterator = 0;
        for (uint256 i = 0; i < s.length_; i++) {
            if (at(s, i) == delimiter) {
                array[iterator++] = slice(s, from, i);
                from = i + 1;
            }
        }
        array[iterator] = slice(s, from, s.length_);
    }
}
