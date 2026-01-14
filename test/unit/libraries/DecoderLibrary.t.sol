// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../../scripts/common/interfaces/ICCIPRouterClient.sol";
import "../../../src/libraries/DecoderLibrary.sol";

contract Unit is Test {
    struct Pair {
        bytes32 a;
        bytes[] b;
        bytes[] c;
        bytes[] d;
        bytes[] e;
        bytes[] f;
    }

    struct X {
        bytes[] a;
        bytes[] b;
    }

    function testDecoderLibrary() external view {
        CCIPClient.EVM2AnyMessage[] memory messages = new CCIPClient.EVM2AnyMessage[](1);
        CCIPClient.EVM2AnyMessage memory message;
        message.receiver = "1";
        message.data = "2";
        message.tokenAmounts = new CCIPClient.EVMTokenAmount[](1);
        message.tokenAmounts[0].token = address(3);
        message.tokenAmounts[0].amount = 4;
        message.feeToken = address(5);
        message.extraArgs = "6";
        messages[0] = message;

        DecoderLibrary.Tree[] memory layer3 = new DecoderLibrary.Tree[](2);
        layer3[0] = DecoderLibrary.Tree(DecoderLibrary.Type.WORD, new DecoderLibrary.Tree[](0));
        layer3[1] = DecoderLibrary.Tree(DecoderLibrary.Type.WORD, new DecoderLibrary.Tree[](0));

        DecoderLibrary.Tree[] memory layer2 = new DecoderLibrary.Tree[](1);
        layer2[0] = DecoderLibrary.Tree(DecoderLibrary.Type.TUPLE, layer3);

        DecoderLibrary.Tree[] memory layer1 = new DecoderLibrary.Tree[](5);
        layer1[0] = DecoderLibrary.Tree(DecoderLibrary.Type.BYTES, new DecoderLibrary.Tree[](0));
        layer1[1] = DecoderLibrary.Tree(DecoderLibrary.Type.BYTES, new DecoderLibrary.Tree[](0));

        layer1[2] = DecoderLibrary.Tree(DecoderLibrary.Type.ARRAY, layer2);

        layer1[3] = DecoderLibrary.Tree(DecoderLibrary.Type.WORD, new DecoderLibrary.Tree[](0));
        layer1[4] = DecoderLibrary.Tree(DecoderLibrary.Type.BYTES, new DecoderLibrary.Tree[](0));

        DecoderLibrary.Tree[] memory layer0 = new DecoderLibrary.Tree[](1);
        layer0[0] = DecoderLibrary.Tree(DecoderLibrary.Type.TUPLE, layer1);

        DecoderLibrary.Tree memory tree = DecoderLibrary.Tree(DecoderLibrary.Type.ARRAY, layer0);
        DecoderLibrary.Value memory value = DecoderLibrary.decode(abi.encode(messages), tree);
        // DecoderLibrary.dfs(value);
    }
}
