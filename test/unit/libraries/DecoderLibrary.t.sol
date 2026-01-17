// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../../../scripts/common/interfaces/ICCIPRouterClient.sol";
import "../../../src/libraries/DecoderLibrary.sol";

import "../../utils/StringView.sol";
import "../../utils/TreeBuilder.sol";

contract Unit is Test {
    using StringView for StringView.View;

    function testEncode() external pure {
        uint256[] memory array = new uint256[](3);
        array[0] = 1;
        array[1] = 2;
        array[2] = 3;

        uint256[][] memory array2 = new uint256[][](1);
        array2[0] = array;

        Value[] memory layer1 = new Value[](3);
        layer1[0] = Value(abi.encode(1), new Value[](0));
        layer1[1] = Value(abi.encode(2), new Value[](0));
        layer1[2] = Value(abi.encode(3), new Value[](0));

        Value[] memory layer0 = new Value[](1);
        layer0[0] = Value("", layer1);

        Value memory value = Value("", layer0);
        bytes memory encodedValue = DecoderLibrary.encode(value, TreeBuilder.fromString("uint256[][]"));

        assertEq(keccak256(abi.encode(array2)), keccak256(encodedValue));
    }

    struct T {
        uint256 a;
        bytes b;
        uint256[] c;
    }

    function testEncode2() external pure {
        Value[] memory layer1 = new Value[](5);
        layer1[0] = Value(abi.encode(1), new Value[](0));
        layer1[1] = Value(abi.encode(2), new Value[](0));
        layer1[2] = Value(abi.encode(3), new Value[](0));
        layer1[3] = Value(abi.encode(4), new Value[](0));
        layer1[4] = Value(abi.encode(5), new Value[](0));

        Value[] memory layer0 = new Value[](3);
        layer0[0] = Value(abi.encode(0x1234), new Value[](0));
        layer0[1] = Value(abi.encode(0x1234), new Value[](0));
        layer0[2] = Value("", layer1);

        Value memory value = Value("", layer0);
        bytes memory encodedValue = DecoderLibrary.encode(value, TreeBuilder.fromString("(uint256,bytes,uint256[])"));
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
        Value[] memory layer4 = new Value[](2);
        layer4[0] = Value(abi.encode(0x12345), new Value[](0));
        layer4[1] = Value(abi.encode(0x12345), new Value[](0));

        Value[] memory layer3 = new Value[](2);
        layer3[0] = Value(abi.encode(bytes32("a")), new Value[](0));
        layer3[1] = Value(abi.encode(bytes32("b")), new Value[](0));

        Value[] memory layer3_ = new Value[](2);
        layer3_[0] = Value(abi.encode(0), new Value[](0));
        layer3_[1] = Value(abi.encode(0), new Value[](0));

        Value[] memory layer2 = new Value[](5);
        layer2[0] = Value("", layer3);
        layer2[1] = Value("", layer3_);
        layer2[2] = Value("", layer3_);
        layer2[3] = Value("", layer3_);
        layer2[4] = Value("", layer3_);

        Value[] memory layer1 = new Value[](1);
        layer1[0] = Value("", layer2);

        Value[] memory layer0 = new Value[](4);
        layer0[0] = Value("", layer1);
        layer0[1] = Value("", layer4);
        layer0[2] = Value("", layer1);
        layer0[3] = Value(abi.encode(0x12345), new Value[](0));

        Value memory value = Value("", layer0);

        bytes memory encodedValue = DecoderLibrary.encode(
            value, TreeBuilder.fromString("((bytes32,bytes32)[][],(bytes32,bytes),(bytes32,bytes32)[][],bytes)")
        );

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

        string memory type_ = "(bytes,bytes,(word,word)[],word,bytes)[]";
        Tree memory tree = TreeBuilder.fromString(type_);
        Value memory value = DecoderLibrary.decode(abi.encode(messages), tree);
        require(value.children.length >= 0);
        assertEq(keccak256(bytes(TreeBuilder.toString(tree))), keccak256(bytes(type_)));
    }
}
