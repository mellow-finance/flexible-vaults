// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {DecoderLibrary, Tree, Type, Value} from "../libraries/DecoderLibrary.sol";
import "../permissions/MellowACL.sol";

import "../vaults/Subvault.sol";
import "../vaults/Vault.sol";

contract FlexibleStrategy is MellowACL {
    enum ActionType {
        READ,
        CALL,
        MOVE_LIQUIDITY
    }

    enum VertexType {
        CONSTANT,
        INPUT,
        RESULT,
        PARENT
    }

    struct InputValue {
        VertexType vertexType;
        bytes data;
        uint256[] edges;
    }

    struct Vertex {
        Type t;
        uint256[] edges;
    }

    struct Action {
        ActionType actionType;
        InputValue[] inputValues;
        Vertex[] inputTypes;
        Vertex[] outputTypes;
        bytes data;
        IVerifier.VerificationPayload payload; // only for `CALL`
    }

    bytes32 public constant EXECUTOR_ROLE = keccak256("executor-role");

    Vault public vault;

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    function initialize(bytes calldata data) external initializer {
        (address admin_, address vault_) = abi.decode(data, (address, address));
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        vault = Vault(payable(vault_));
    }

    function execute(Action[] calldata actions, bytes[] calldata inputs) external onlyRole(EXECUTOR_ROLE) {
        Value[] memory responses = new Value[](actions.length);
        for (uint256 i = 0; i < actions.length; i++) {
            Action calldata action = actions[i];
            if (action.actionType == ActionType.CALL) {
                (address subvault, address where, bytes4 selector) = abi.decode(action.data, (address, address, bytes4));
                (Value memory inputValue, Tree memory inputTree) = _buildInputValue(i, actions, inputs, responses);
                if (inputValue.t != Type.TUPLE || inputValue.children.length != 2) {
                    revert("Invalid inputValue type");
                }
                Value memory msgValue = inputValue.children[0];
                if (!DecoderLibrary.isValidWord(msgValue)) {
                    revert("Invalid msg.value type");
                }
                bytes memory response = ICallModule(subvault).call(
                    where,
                    abi.decode(msgValue.data, (uint256)),
                    bytes.concat(
                        abi.encodePacked(selector), DecoderLibrary.encode(inputValue.children[1], inputTree.children[1])
                    ),
                    action.payload
                );
                responses[i] = DecoderLibrary.decode(response, _buildTree(action.outputTypes));
            } else if (action.actionType == ActionType.MOVE_LIQUIDITY) {
                (address source, address target, address asset) = abi.decode(action.data, (address, address, address));
                (Value memory value,) = _buildInputValue(i, actions, inputs, responses);
                if (!DecoderLibrary.isValidWord(value)) {
                    revert("Invalid amount type");
                }
                uint256 amount = abi.decode(value.data, (uint256));
                if (source == address(vault)) {
                    vault.pushAssets(target, asset, amount);
                } else if (target == address(vault)) {
                    vault.pullAssets(source, asset, amount);
                } else {
                    vault.pullAssets(source, asset, amount);
                    vault.pushAssets(target, asset, amount);
                }
                Value[] memory info = new Value[](4);
                info[0] = Value(Type.WORD, abi.encode(source), new Value[](0));
                info[1] = Value(Type.WORD, abi.encode(target), new Value[](0));
                info[2] = Value(Type.WORD, abi.encode(asset), new Value[](0));
                info[3] = Value(Type.WORD, abi.encode(amount), new Value[](0));
                responses[i] = Value(Type.TUPLE, "", info);
            } else {
                (address target, bytes4 selector) = abi.decode(action.data, (address, bytes4));
                (Value memory value, Tree memory tree) = _buildInputValue(i, actions, inputs, responses);
                bytes memory data = DecoderLibrary.encode(value, tree);
                bytes memory response =
                    Address.functionStaticCall(target, bytes.concat(abi.encodePacked(selector), data));
                responses[i] = DecoderLibrary.decode(response, _buildTree(action.outputTypes));
            }
        }
    }

    function _buildTree(Vertex[] calldata vertices) internal pure returns (Tree memory) {
        uint256 n = vertices.length;
        Tree[] memory trees = new Tree[](n);
        for (uint256 i = 0; i < n; i++) {
            trees[i].t = vertices[i].t;
            uint256[] calldata edges = vertices[i].edges;
            trees[i].children = new Tree[](edges.length);
            for (uint256 j = 0; j < edges.length; j++) {
                uint256 to = edges[j];
                if (to <= i) {
                    revert("Invalid edge");
                }
                trees[i].children[j] = trees[to];
            }
        }
        return trees[0];
    }

    function _buildInputValue(
        uint256 actionIndex,
        Action[] calldata actions,
        bytes[] calldata inputs,
        Value[] memory responses
    ) internal pure returns (Value memory value, Tree memory tree) {
        tree = _buildTree(actions[actionIndex].inputTypes);
        value = _buildInputValue(tree, 0, actions[actionIndex].inputValues, actions, inputs, responses);
    }

    function _buildInputValue(
        Tree memory tree,
        uint256 v,
        InputValue[] calldata inputValues,
        Action[] calldata actions,
        bytes[] calldata inputs,
        Value[] memory responses
    ) internal pure returns (Value memory value) {
        InputValue calldata vertex = inputValues[v];
        if (vertex.vertexType == VertexType.CONSTANT || vertex.vertexType == VertexType.INPUT) {
            Type t = tree.t;
            bytes calldata data;
            if (vertex.vertexType == VertexType.CONSTANT) {
                data = vertex.data;
            } else {
                data = inputs[abi.decode(vertex.data, (uint256))];
            }
            if (t == Type.WORD) {
                if (data.length != 0x20) {
                    revert("Invalid word lenth");
                }
            } else if (t != Type.BYTES) {
                revert("Unsupported leaf type");
            }
            return Value(t, data, new Value[](0));
        } else if (vertex.vertexType == VertexType.RESULT) {
            (uint256 responseIndex, uint256[] memory path) = abi.decode(vertex.data, (uint256, uint256[]));
            Tree memory outputTree = _buildTree(actions[responseIndex].outputTypes);
            outputTree = DecoderLibrary.traverse(outputTree, path, 0);
            if (!DecoderLibrary.compare(outputTree, tree)) {
                revert("Invalid result type");
            }
            return DecoderLibrary.traverse(responses[responseIndex], path, 0);
        } else {
            if (tree.t == Type.WORD || tree.t == Type.BYTES) {
                revert("Invalid parent type");
            } else if (tree.t == Type.ARRAY) {
                value.t = tree.t;
                value.children = new Value[](vertex.edges.length);
                for (uint256 i = 0; i < vertex.edges.length; i++) {
                    value.children[i] =
                        _buildInputValue(tree.children[0], vertex.edges[i], inputValues, actions, inputs, responses);
                }
            } else {
                value.t = tree.t;
                value.children = new Value[](vertex.edges.length);
                for (uint256 i = 0; i < vertex.edges.length; i++) {
                    value.children[i] =
                        _buildInputValue(tree.children[i], vertex.edges[i], inputValues, actions, inputs, responses);
                }
            }
        }
    }
}

import "forge-std/console2.sol";
