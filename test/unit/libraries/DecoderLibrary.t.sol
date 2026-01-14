// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../../scripts/common/interfaces/ICCIPRouterClient.sol";
import "../../../src/libraries/DecoderLibrary.sol";

contract Unit is Test {
    function testEncode() external pure {
        uint256[] memory array = new uint256[](3);
        array[0] = 1;
        array[1] = 2;
        array[2] = 3;

        uint256[][] memory array2 = new uint256[][](1);
        array2[0] = array;

        DecoderLibrary.Value[] memory layer1 = new DecoderLibrary.Value[](3);
        layer1[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(1), new DecoderLibrary.Value[](0));
        layer1[1] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(2), new DecoderLibrary.Value[](0));
        layer1[2] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(3), new DecoderLibrary.Value[](0));

        DecoderLibrary.Value[] memory layer0 = new DecoderLibrary.Value[](1);
        layer0[0] = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer1);

        DecoderLibrary.Value memory value = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer0);
        bytes memory encodedValue = DecoderLibrary.encode(value);

        assertEq(keccak256(abi.encode(array2)), keccak256(encodedValue));
    }

    struct T {
        uint256 a;
        bytes b;
        uint256[] c;
    }

    function testEncode2() external pure {
        DecoderLibrary.Value[] memory layer1 = new DecoderLibrary.Value[](5);
        layer1[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(1), new DecoderLibrary.Value[](0));
        layer1[1] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(2), new DecoderLibrary.Value[](0));
        layer1[2] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(3), new DecoderLibrary.Value[](0));
        layer1[3] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(4), new DecoderLibrary.Value[](0));
        layer1[4] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(5), new DecoderLibrary.Value[](0));

        DecoderLibrary.Value[] memory layer0 = new DecoderLibrary.Value[](3);
        layer0[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(0x1234), new DecoderLibrary.Value[](0));
        layer0[1] = DecoderLibrary.Value(DecoderLibrary.Type.BYTES, abi.encode(0x1234), new DecoderLibrary.Value[](0));
        layer0[2] = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer1);

        DecoderLibrary.Value memory value = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer0);
        bytes memory encodedValue = DecoderLibrary.encode(value);
        uint256[] memory array = new uint256[](5);
        array[0] = 1;
        array[1] = 2;
        array[2] = 3;
        array[3] = 4;
        array[4] = 5;
        assertEq(keccak256(abi.encode(T(0x1234, abi.encode(0x1234), array))), keccak256(encodedValue));
    }

    struct Pair {
        bytes32 a;
        bytes32 b;
    }

    struct Y {
        bytes32 a;
        bytes b;
    }

    struct Q {
        Pair[][] a;
        Y c;
        Pair[][] b;
        bytes d;
    }

    function testEncode3() external pure {
        DecoderLibrary.Value[] memory layer4 = new DecoderLibrary.Value[](2);
        layer4[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(0x12345), new DecoderLibrary.Value[](0));
        layer4[1] = DecoderLibrary.Value(DecoderLibrary.Type.BYTES, abi.encode(0x12345), new DecoderLibrary.Value[](0));

        DecoderLibrary.Value[] memory layer3 = new DecoderLibrary.Value[](2);
        layer3[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, "a", new DecoderLibrary.Value[](0));
        layer3[1] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, "b", new DecoderLibrary.Value[](0));

        DecoderLibrary.Value[] memory layer3_ = new DecoderLibrary.Value[](2);
        layer3_[0] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(0), new DecoderLibrary.Value[](0));
        layer3_[1] = DecoderLibrary.Value(DecoderLibrary.Type.WORD, abi.encode(0), new DecoderLibrary.Value[](0));

        DecoderLibrary.Value[] memory layer2 = new DecoderLibrary.Value[](5);
        layer2[0] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer3);
        layer2[1] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer3_);
        layer2[2] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer3_);
        layer2[3] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer3_);
        layer2[4] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer3_);

        DecoderLibrary.Value[] memory layer1 = new DecoderLibrary.Value[](1);
        layer1[0] = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer2);

        DecoderLibrary.Value[] memory layer0 = new DecoderLibrary.Value[](4);
        layer0[0] = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer1);
        layer0[1] = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer4);
        layer0[2] = DecoderLibrary.Value(DecoderLibrary.Type.ARRAY, "", layer1);
        layer0[3] = DecoderLibrary.Value(DecoderLibrary.Type.BYTES, abi.encode(0x12345), new DecoderLibrary.Value[](0));

        DecoderLibrary.Value memory value = DecoderLibrary.Value(DecoderLibrary.Type.TUPLE, "", layer0);

        bytes memory encodedValue = DecoderLibrary.encode(value);

        Pair[][] memory array = new Pair[][](1);
        array[0] = new Pair[](5);
        array[0][0].a = "a";
        array[0][0].b = "b";

        assertEq(
            keccak256(
                abi.encode(Q(array, Y(bytes32(uint256(0x12345)), abi.encode(0x12345)), array, abi.encode(0x12345)))
            ),
            keccak256(encodedValue)
        );
    }

    function testDecoderLibrary() external pure {
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
        require(value.children.length >= 0);
        // DecoderLibrary.dfs(value);
    }
}
