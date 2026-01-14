// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../libraries/DecoderLibrary.sol";
import "../permissions/MellowACL.sol";

import "../vaults/Subvault.sol";
import "../vaults/Vault.sol";

contract FlexibleStrategy is MellowACL {
    enum ActionType {
        CALL,
        PUSH,
        PULL,
        EXTRACT,
        COMBINE_TO_TUPLE,
        COMBINE_TO_ARRAY,
        COMBINE_TO_BYTES
    }

    struct Action {
        address subvault;
        ActionType actionType;
        bytes outputTypes;
        bytes data;
    }

    bytes32 public constant EXECUTOR_ROLE = keccak256("executor-role");

    Vault public vault;
    mapping(bytes32 => bool) public whitelistedActions;

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    function initialize(bytes calldata data) external initializer {
        (address admin_, address vault_) = abi.decode(data, (address, address));
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        vault = Vault(payable(vault_));
    }

    function execute(Action[] calldata actions) external onlyRole(EXECUTOR_ROLE) {
        DecoderLibrary.Value[] memory responses = new DecoderLibrary.Value[](actions.length);
        for (uint256 i = 0; i < actions.length; i++) {
            ActionType type_ = actions[i].actionType;
            if (type_ == ActionType.CALL) {
                (address where, uint256 value, bytes memory data, IVerifier.VerificationPayload memory payload) =
                    abi.decode(actions[i].data, (address, uint256, bytes, IVerifier.VerificationPayload));
                responses[i] = DecoderLibrary.decode(
                    Subvault(payable(actions[i].subvault)).call(where, value, data, payload),
                    DecoderLibrary.buildTree(actions[i].outputTypes)
                );
            } else if (type_ == ActionType.PULL) {
                (address asset, uint256 value) = abi.decode(actions[i].data, (address, uint256));
                vault.pullAssets(actions[i].subvault, asset, value);
            } else if (type_ == ActionType.PUSH) {
                (address asset, uint256 value) = abi.decode(actions[i].data, (address, uint256));
                vault.pushAssets(actions[i].subvault, asset, value);
            } else if (type_ == ActionType.EXTRACT) {
                (uint256 responseIndex, uint256[] memory path) = abi.decode(actions[i].data, (uint256, uint256[]));
                responses[i] = DecoderLibrary.traverse(responses[responseIndex], path, 0);
            } else if (type_ == ActionType.COMBINE_TO_TUPLE) {
                uint256[] memory responseIndices = abi.decode(actions[i].data, (uint256[]));
                responses[i].t = DecoderLibrary.Type.TUPLE;
                responses[i].children = new DecoderLibrary.Value[](responseIndices.length);
                for (uint256 index = 0; index < responseIndices.length; index++) {
                    responses[i].children[index] = responses[responseIndices[index]];
                }
            } else if (type_ == ActionType.COMBINE_TO_ARRAY) {
                uint256[] memory responseIndices = abi.decode(actions[i].data, (uint256[]));
                DecoderLibrary.Tree memory tree = DecoderLibrary.buildTree(actions[i].outputTypes);
                require(tree.t == DecoderLibrary.Type.ARRAY);
                bytes32 childHash = DecoderLibrary.getTypeHash(tree.children[0]);
                responses[i].t = DecoderLibrary.Type.ARRAY;
                responses[i].children = new DecoderLibrary.Value[](responseIndices.length);
                for (uint256 index = 0; index < responseIndices.length; index++) {
                    if (DecoderLibrary.getTypeHash(responses[responseIndices[index]]) != childHash) {
                        revert("Child type mismatch");
                    }
                    responses[i].children[index] = responses[responseIndices[index]];
                }
            } else if (type_ == ActionType.COMBINE_TO_BYTES) {
                // uint256 responseIndex = abi.decode(actions[i].data, (uint256));
                // responses[i].t = DecoderLibrary.Type.BYTES;
                // responses[i].data = DecoderLibrary.encode(responses[responseIndex]);
            }
        }
    }
}
