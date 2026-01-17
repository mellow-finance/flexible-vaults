// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/libraries/DecoderLibrary.sol";
import "./StringView.sol";

library TreeBuilder {
    error InvalidString();
    error InvalidStaticArrayLength();

    using StringView for StringView.View;

    function build(StringView.View memory s) internal pure returns (Tree memory tree) {
        if (s.length() == 0) {
            revert InvalidString();
        }

        if (s.endswith("[]")) {
            tree.t = Type.ARRAY;
            tree.children = new Tree[](1);
            tree.children[0] = build(s.slice(0, s.length() - 2));
            return tree;
        }

        if (s.endswith("]")) {
            tree.t = Type.TUPLE;
            for (uint256 i = s.length() - 2;; i--) {
                if (i == 0) {
                    revert InvalidString();
                }
                if (s.at(i) == "[") {
                    uint256 n = s.slice(i + 1, s.length() - 1).toUint();
                    if (n == 0) {
                        revert InvalidStaticArrayLength();
                    }
                    Tree memory child = build(s.slice(0, i));
                    tree.children = new Tree[](n);
                    for (uint256 j = 0; j < n; j++) {
                        tree.children[j] = child;
                    }
                    return tree;
                }
            }
            revert InvalidString();
        }

        if (s.startswith("(")) {
            s = s.slice(1, s.length() - 1);
            uint256 level = 0;
            uint256 n = 1;
            for (uint256 i = 0; i < s.length(); i++) {
                if (s.at(i) == "(") {
                    ++level;
                } else if (s.at(i) == ")") {
                    --level;
                } else if (level == 0 && s.at(i) == ",") {
                    ++n;
                }
            }
            if (level != 0) {
                revert InvalidString();
            }
            tree.children = new Tree[](n);
            uint256 iterator = 0;
            uint256 from = 0;
            for (uint256 i = 0; i < s.length(); i++) {
                if (s.at(i) == "(") {
                    ++level;
                } else if (s.at(i) == ")") {
                    --level;
                } else if (level == 0 && s.at(i) == ",") {
                    tree.children[iterator++] = build(s.slice(from, i));
                    from = i + 1;
                }
            }
            tree.children[iterator] = build(s.slice(from, s.length()));
            return tree;
        }

        if (s.equalsTo("bytes")) {
            return Tree(Type.BYTES, new Tree[](0));
        } else {
            return Tree(Type.WORD, new Tree[](0));
        }
    }

    function build(string memory s) internal pure returns (Tree memory) {
        return build(StringView.init(s));
    }
}
