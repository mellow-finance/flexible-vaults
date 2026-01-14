// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../permissions/MellowACL.sol";
import "../vaults/Vault.sol";

contract FlexibleStrategy is MellowACL {
    enum Type {
        WORD,
        TUPLE,
        ARRAY
    }

    struct SolidityValue {
        Type element;
        SolidityValue[] children;
    }

    enum ActionType {
        CALL,
        PUSH,
        PULL
    }

    struct Action {
        address subvault;
        ActionType actionType;
        bytes data;
    }

    bytes32 public constant EXECUTOR_ROLE = keccak256("executor-role");
    bytes32 public constant ARBITRARY_EXECUTOR_ROLE = keccak256("arbitrary-executor-role");

    Vault public vault;
    mapping(bytes32 => bool) public whitelistedActions;

    constructor(string memory name_, uint256 version_) MellowACL(name_, version_) {}

    function initialize(bytes calldata data) external initializer {
        (address admin_, address vault_) = abi.decode(data, (address, address));
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        vault = Vault(payable(vault_));
    }

    function fetchData(bytes[] memory responses, Action[] calldata actions, uint256 actionIndex)
        public
        view
        returns (bytes memory)
    {}

    // function execute(Action[] calldata actions, bytes[] calldata inputs) external onlyRole(EXECUTOR_ROLE) {
    //     if (!hasRole(ARBITRARY_EXECUTOR_ROLE, _msgSender())) {
    //         bytes32 hash_ = keccak256(abi.encode(actions));
    //         if (!whitelistedActions[hash_]) {
    //             revert("forbidden");
    //         }
    //     }

    //     bytes[] memory responses = new bytes[](actions.length);
    //     for (uint256 i = 0; i < actions.length; i++) {
    //         ActionType type_ = actions[i].actionType;
    //         if (type_ == ActionType.CALL) {} else if (type_ == ActionType.PULL) {
    //             (address asset, uint256 amount) = abi.decode(actions[i].data);
    //             vault.pullAssets(actions[i].subvault, asset, value);
    //         } else if (type_ == ActionType.PUSH) {
    //             (address asset, uint256 amount) = abi.decode(actions[i].data);
    //             vault.pushAssets(actions[i].subvault, asset, value);
    //         }
    //     }
    // }
}
